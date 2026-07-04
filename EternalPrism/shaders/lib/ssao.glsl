//================================================
// Eternal Prism — SSAO (без артефактов в пещерах)
//================================================

vec3 ssaoReconstructPos(vec2 uv, float depth, mat4 projInv) {
    vec4 c = projInv * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return c.xyz / c.w;
}

vec3 ssaoNormal(sampler2D depthTex, vec2 uv, mat4 projInv, float vw, float vh) {
    vec2 t = vec2(1.0/vw, 1.0/vh);
    float dc = texture2D(depthTex, uv).r;
    float dr = texture2D(depthTex, uv + vec2(t.x, 0.0)).r;
    float du = texture2D(depthTex, uv + vec2(0.0, t.y)).r;

    // защита от резких перепадов глубины (края блоков, пещеры)
    // если соседний пиксель слишком далеко — используем центральный
    float dr2 = texture2D(depthTex, uv - vec2(t.x, 0.0)).r;
    float du2 = texture2D(depthTex, uv - vec2(0.0, t.y)).r;
    if (abs(dr - dc) > abs(dr2 - dc)) dr = dr2;
    if (abs(du - dc) > abs(du2 - dc)) du = du2;

    vec3 p0 = ssaoReconstructPos(uv, dc, projInv);
    vec3 px = ssaoReconstructPos(uv + vec2(t.x, 0), dr, projInv);
    vec3 py = ssaoReconstructPos(uv + vec2(0, t.y), du, projInv);

    vec3 N = normalize(cross(px - p0, py - p0));
    return (isnan(N.x) || isnan(N.y) || isnan(N.z)) ? vec3(0.0, 0.0, -1.0) : N;
}

float calcSSAO(sampler2D depthTex, vec2 uv, float depth, mat4 projInv, mat4 proj,
               float vw, float vh, float time) {
    if (depth >= 1.0) return 1.0;

    vec3 pos = ssaoReconstructPos(uv, depth, projInv);
    vec3 N   = ssaoNormal(depthTex, uv, projInv, vw, vh);

    // в пещерах (далеко от поверхности) отключаем SSAO — там блочный свет, не небесный
    // pos.z — расстояние до камеры, используем как прокси
    float distFade = smoothstep(60.0, 30.0, -pos.z);
    if (distFade < 0.01) return 1.0;

    const float PHI = 2.399963;
    float radius = 0.45;
    float ao = 0.0;

    // случайное вращение на каждый пиксель — ломает регулярный паттерн
    float angle = fract(sin(dot(uv * vec2(vw, vh), vec2(127.1, 311.7))) * 43758.5453) * 6.2832;
    float cosA = cos(angle), sinA = sin(angle);

    for (int i = 0; i < SSAO_SAMPLES; i++) {
        float fi    = float(i) + 0.5;
        float r     = sqrt(fi / float(SSAO_SAMPLES));
        float theta = fi * PHI;

        vec2 disk = vec2(cos(theta)*r, sin(theta)*r);
        // вращаем 2D часть kernel случайно
        disk = vec2(disk.x*cosA - disk.y*sinA, disk.x*sinA + disk.y*cosA);

        vec3 kernel = vec3(disk, sqrt(max(0.0, 1.0 - dot(disk,disk))));
        if (dot(kernel, N) < 0.0) kernel = -kernel;
        kernel *= radius;

        vec3 sp  = pos + kernel;
        vec4 off = proj * vec4(sp, 1.0);
        off.xyz  = off.xyz / off.w * 0.5 + 0.5;
        if (off.x < 0.0 || off.x > 1.0 || off.y < 0.0 || off.y > 1.0) continue;

        float sd  = texture2D(depthTex, off.xy).r;
        vec3  srp = ssaoReconstructPos(off.xy, sd, projInv);

        // защита: если сэмпл слишком далеко по Z — игнорируем (края блоков)
        float zDiff = abs(pos.z - srp.z);
        if (zDiff > radius * 4.0) continue;

        float rng = smoothstep(0.0, 1.0, radius / max(zDiff, 0.001));
        ao += (srp.z >= sp.z + 0.018) ? rng : 0.0;
    }

    float result = 1.0 - (ao / float(SSAO_SAMPLES)) * 1.2;
    return mix(1.0, result, distFade);
}
