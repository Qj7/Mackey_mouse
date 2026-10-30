import {
  BufferAttribute,
  BufferGeometry,
  Color,
  DynamicDrawUsage,
  InstancedBufferAttribute,
  InstancedBufferGeometry,
  LineSegments,
  LinearSRGBColorSpace,
  Mesh,
  PerspectiveCamera,
  Scene,
  ShaderMaterial,
  SphereGeometry,
  WebGLRenderer,
} from "three";

const COLOR = 0x7c5cff;
const BACKGROUND = 0x2d1b69;
const POINTS = 9;
const SPACING = 18;
const MAX_DISTANCE = 22;
const MIN_SIZE = 200;
const FRAME_MS = 1000 / 60;

// Colors are written straight to the framebuffer, matching the pre-r152 pipeline
// without color management that the original effect was tuned for.
const linear = (hex: number) => new Color().setHex(hex, LinearSRGBColorSpace);

const rn = (min: number, max: number) => min + Math.random() * (max - min);
const ri = (min: number, max: number) => Math.floor(min + Math.random() * (max - min + 1));

// Reproduces the legacy (non-physical) per-vertex Lambert shading under
// AmbientLight(0.75) and SpotLight(1) at (0, 200, 0) with distance 400, decay 1.
const dotVertexShader = /* glsl */ `
  attribute vec3 offset;
  uniform vec3 color;
  varying vec3 vColor;

  void main() {
    vec3 world = position + offset;
    vec3 toLight = vec3(0.0, 200.0, 0.0) - world;
    float dist = length(toLight);
    toLight /= dist;
    float spot = step(0.5, toLight.y) * clamp(1.0 - dist / 400.0, 0.0, 1.0);
    vColor = color * (0.75 + max(dot(normal, toLight), 0.0) * spot);
    gl_Position = projectionMatrix * modelViewMatrix * vec4(world, 1.0);
  }
`;

const dotFragmentShader = /* glsl */ `
  varying vec3 vColor;

  void main() {
    gl_FragColor = vec4(vColor, 1.0);
  }
`;

const lineVertexShader = /* glsl */ `
  attribute float alpha;
  varying float vAlpha;

  void main() {
    vAlpha = alpha;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const lineFragmentShader = /* glsl */ `
  uniform vec3 color;
  uniform vec3 background;
  varying float vAlpha;

  void main() {
    gl_FragColor = vec4(mix(background, color, vAlpha), 1.0);
  }
`;

export function mountNetScene(el: HTMLElement) {
  const mobile =
    /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) ||
    window.innerWidth < 600;
  const n = mobile ? Math.floor(POINTS * 0.75) : POINTS;
  const spacing = mobile ? Math.floor(SPACING * 0.65) : SPACING;

  const count = (n + 1) * (n + 1) * 2;
  const positions = new Float32Array(count * 3);
  const radius = new Float32Array(count);
  const angle = new Float32Array(count);
  const rate = new Float32Array(count);

  let added = 0;
  const addPoint = (x: number, y: number, z: number) => {
    positions[added * 3] = x;
    positions[added * 3 + 1] = y;
    positions[added * 3 + 2] = z;
    radius[added] = Math.hypot(x, z);
    angle[added] = Math.atan2(z, x);
    rate[added] = 0.00025 * rn(-2, 2);
    added++;
  };

  for (let i = 0; i <= n; i++) {
    for (let j = 0; j <= n; j++) {
      const y = ri(-3, 3);
      const x = (i - n / 2) * spacing + ri(-5, 5);
      let z = (j - n / 2) * spacing + ri(-5, 5);
      if (i % 2) z += spacing * 0.5;
      addPoint(x, y - ri(5, 15), z);
      addPoint(x + ri(-5, 5), y + ri(5, 15), z + ri(-5, 5));
    }
  }

  const renderer = new WebGLRenderer({ alpha: true, antialias: true, powerPreference: "low-power" });
  renderer.setClearColor(0x000000, 0);
  const canvas = renderer.domElement;
  canvas.style.position = "absolute";
  canvas.style.top = "0";
  canvas.style.left = "0";
  el.appendChild(canvas);

  const scene = new Scene();
  const camera = new PerspectiveCamera(25, 1, 0.01, 10000);
  camera.position.set(50, 100, 150);
  const orbitRadius = Math.hypot(camera.position.x, camera.position.z);
  const orbitAngle = Math.atan2(camera.position.z, camera.position.x);
  let targetX = camera.position.x;
  let targetY = camera.position.y;

  const sphere = new SphereGeometry(0.25, 12, 12);
  const dotGeometry = new InstancedBufferGeometry();
  dotGeometry.setIndex(sphere.index);
  dotGeometry.setAttribute("position", sphere.getAttribute("position"));
  dotGeometry.setAttribute("normal", sphere.getAttribute("normal"));
  dotGeometry.instanceCount = count;
  const offsetAttribute = new InstancedBufferAttribute(positions, 3).setUsage(DynamicDrawUsage);
  dotGeometry.setAttribute("offset", offsetAttribute);
  const dotMaterial = new ShaderMaterial({
    uniforms: { color: { value: linear(COLOR) } },
    vertexShader: dotVertexShader,
    fragmentShader: dotFragmentShader,
  });
  const dots = new Mesh(dotGeometry, dotMaterial);
  dots.frustumCulled = false;
  scene.add(dots);

  const maxSegments = (count * (count - 1)) / 2;
  const linePositions = new Float32Array(maxSegments * 6);
  const lineAlphas = new Float32Array(maxSegments * 2);
  const linePositionAttribute = new BufferAttribute(linePositions, 3).setUsage(DynamicDrawUsage);
  const lineAlphaAttribute = new BufferAttribute(lineAlphas, 1).setUsage(DynamicDrawUsage);
  const lineGeometry = new BufferGeometry();
  lineGeometry.setAttribute("position", linePositionAttribute);
  lineGeometry.setAttribute("alpha", lineAlphaAttribute);
  lineGeometry.setDrawRange(0, 0);
  const lineMaterial = new ShaderMaterial({
    uniforms: { color: { value: linear(COLOR) }, background: { value: linear(BACKGROUND) } },
    vertexShader: lineVertexShader,
    fragmentShader: lineFragmentShader,
    transparent: true,
  });
  const lines = new LineSegments(lineGeometry, lineMaterial);
  lines.frustumCulled = false;
  scene.add(lines);

  let width = 0;
  let height = 0;
  let pixelRatio = 0;
  const resize = () => {
    const nextWidth = Math.max(el.offsetWidth, MIN_SIZE);
    const nextHeight = Math.max(el.offsetHeight, MIN_SIZE);
    const nextPixelRatio = window.devicePixelRatio;
    if (nextWidth === width && nextHeight === height && nextPixelRatio === pixelRatio) return;
    width = nextWidth;
    height = nextHeight;
    pixelRatio = nextPixelRatio;
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    renderer.setPixelRatio(pixelRatio);
    renderer.setSize(width, height);
    renderer.render(scene, camera);
  };

  let pointerX = 0;
  let pointerY = 0;
  let pointerDirty = false;
  const setPointer = (x: number, y: number) => {
    pointerX = x;
    pointerY = y;
    pointerDirty = true;
  };
  const onMouseMove = (e: MouseEvent) => setPointer(e.clientX, e.clientY);
  const onTouch = (e: TouchEvent) => {
    if (e.touches.length === 1) setPointer(e.touches[0].clientX, e.touches[0].clientY);
  };

  const applyPointer = () => {
    pointerDirty = false;
    const rect = canvas.getBoundingClientRect();
    const x = pointerX - rect.left;
    const y = pointerY - rect.top;
    if (x < 0 || y < 0 || x > rect.width || y > rect.height) return;
    targetX = orbitRadius * Math.cos(orbitAngle + (x / width - 0.5) * 2);
    targetY = 100 + (y / height - 0.5) * 50;
  };

  const update = (steps: number) => {
    if (pointerDirty) applyPointer();

    const ease = 1 - Math.pow(0.98, steps);
    const dx = targetX - camera.position.x;
    const dy = targetY - camera.position.y;
    if (Math.abs(dx) > 0.01) camera.position.x += dx * ease;
    if (Math.abs(dy) > 0.01) camera.position.y += dy * ease;
    camera.lookAt(0, 0, 0);

    for (let i = 0; i < count; i++) {
      angle[i] += rate[i] * steps;
      positions[i * 3] = radius[i] * Math.cos(angle[i]);
      positions[i * 3 + 2] = radius[i] * Math.sin(angle[i]);
    }
    offsetAttribute.needsUpdate = true;

    const maxDistanceSq = MAX_DISTANCE * MAX_DISTANCE;
    let segments = 0;
    for (let i = 0; i < count; i++) {
      const ax = positions[i * 3];
      const ay = positions[i * 3 + 1];
      const az = positions[i * 3 + 2];
      for (let j = i + 1; j < count; j++) {
        const bx = positions[j * 3];
        const by = positions[j * 3 + 1];
        const bz = positions[j * 3 + 2];
        const distSq = (ax - bx) ** 2 + (ay - by) ** 2 + (az - bz) ** 2;
        if (distSq >= maxDistanceSq) continue;

        const p = segments * 6;
        linePositions[p] = ax;
        linePositions[p + 1] = ay;
        linePositions[p + 2] = az;
        linePositions[p + 3] = bx;
        linePositions[p + 4] = by;
        linePositions[p + 5] = bz;
        const alpha = Math.min((1 - Math.sqrt(distSq) / MAX_DISTANCE) * 2, 1);
        lineAlphas[segments * 2] = alpha;
        lineAlphas[segments * 2 + 1] = alpha;
        segments++;
      }
    }

    lineGeometry.setDrawRange(0, segments * 2);
    if (segments > 0) {
      linePositionAttribute.addUpdateRange(0, segments * 6);
      linePositionAttribute.needsUpdate = true;
      lineAlphaAttribute.addUpdateRange(0, segments * 2);
      lineAlphaAttribute.needsUpdate = true;
    }
  };

  let frame = 0;
  let last = 0;
  const tick = (now: number) => {
    frame = requestAnimationFrame(tick);
    const steps = last ? Math.min(Math.max((now - last) / FRAME_MS, 0.2), 5) : 1;
    last = now;
    update(steps);
    renderer.render(scene, camera);
  };
  const start = () => {
    if (frame) return;
    last = 0;
    frame = requestAnimationFrame(tick);
  };
  const stop = () => {
    cancelAnimationFrame(frame);
    frame = 0;
  };

  update(1);
  resize();

  const resizeObserver = new ResizeObserver(resize);
  resizeObserver.observe(el);
  const intersectionObserver = new IntersectionObserver(([entry]) => {
    if (entry.isIntersecting) start();
    else stop();
  });
  intersectionObserver.observe(el);

  const listenerOptions = { passive: true } as const;
  window.addEventListener("mousemove", onMouseMove, listenerOptions);
  window.addEventListener("touchstart", onTouch, listenerOptions);
  window.addEventListener("touchmove", onTouch, listenerOptions);

  return () => {
    stop();
    resizeObserver.disconnect();
    intersectionObserver.disconnect();
    window.removeEventListener("mousemove", onMouseMove);
    window.removeEventListener("touchstart", onTouch);
    window.removeEventListener("touchmove", onTouch);
    dotGeometry.dispose();
    dotMaterial.dispose();
    lineGeometry.dispose();
    lineMaterial.dispose();
    renderer.dispose();
    canvas.remove();
  };
}
