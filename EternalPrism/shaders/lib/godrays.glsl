//================================================
// Eternal Prism — God rays (оптимизированные)
// Early exit + GODRAYS_SAMPLES
//================================================

float godRays(sampler2D depthTex, vec2 uv, vec2 sunScreenPos, float sunHeight) {
    if (sunHeight < 0.20) return 0.0;

    float DECAY    = 0.958;
    float WEIGHT   = 0.020;
    float DENSITY  = 0.65;
    float EXPOSURE = 0.50;

    vec2  dir    = (uv - sunScreenPos) * DENSITY / float(GODRAYS_SAMPLES);
    vec2  curUV  = uv;
    float light  = 0.0;
    float decay  = 1.0;

    for (int i = 0; i < GODRAYS_SAMPLES; i++) {
        curUV -= dir;
        if (curUV.x < 0.0 || curUV.x > 1.0 || curUV.y < 0.0 || curUV.y > 1.0) break;

        float d = texture2D(depthTex, curUV).r;
        light  += (d >= 1.0 ? 1.0 : 0.0) * decay * WEIGHT;
        decay  *= DECAY;

        // early exit — дальнейшие сэмплы дают < 0.1% вклада
        if (decay < 0.005) break;
    }

    return light * EXPOSURE * smoothstep(0.20, 0.45, sunHeight);
}
