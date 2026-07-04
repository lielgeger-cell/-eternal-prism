//================================================================
// Eternal Prism — Configuration
// Настройки доступны в игре: Video Settings > Shader Packs > Options
//================================================================

#define LOW 0
#define HIGH 1
#define SUPER_HIGH 2
#define ULTRA 3

//=== ОСНОВНОЕ ===
#define SHADER_QUALITY HIGH // Общее качество. Влияет на всё сразу [LOW HIGH SUPER_HIGH ULTRA]

//=== ИЗОБРАЖЕНИЕ ===
#define BRIGHTNESS 1.0     // Яркость [0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4]
#define SATURATION 1.0     // Насыщенность [0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4]
#define CONTRAST 1.0       // Контраст [0.8 0.9 1.0 1.1 1.2]
#define TONEMAP_EXPOSURE 0.85 // Экспозиция тонмаппинга [0.7 0.75 0.8 0.85 0.9 1.0]

//=== ЭФФЕКТЫ (можно выключать по отдельности) ===
#define ENABLE_VOLUMETRIC 1   // Объёмные лучи света [0 1]
#define ENABLE_SSAO 1         // Затенение в углах [0 1]
#define ENABLE_SSR 1          // Отражения на воде [0 1]
#define ENABLE_BLOOM 1        // Свечение ярких мест [0 1]
#define ENABLE_DOF 1          // Размытие дали (глубина резкости) [0 1]
#define ENABLE_AURORA 1       // Северное сияние ночью [0 1]
#define ENABLE_CLOUDS 1       // Процедурные облака [0 1]
#define ENABLE_STARS 1        // Звёздное небо, млечный путь [0 1]
#define ENABLE_GRAIN 1        // Плёночное зерно [0 1]
#define ENABLE_CHROMATIC 1    // Хроматическая аберрация [0 1]
#define ENABLE_IRIDESCENCE 1  // Радужные блики на воде [0 1]
#define ENABLE_WETNESS 1      // Мокрые поверхности в дождь [0 1]

//=== ВОДА ===
#define WATER_WAVE_HEIGHT 1.0 // Высота волн [0.5 0.75 1.0 1.25 1.5]
#define WATER_OPACITY 1.0     // Непрозрачность воды [0.7 0.85 1.0 1.15]
#define WATER_CAUSTICS 1      // Каустики (блики на дне) [0 1]

//=== АТМОСФЕРА ===
#define FOG_DENSITY 1.0       // Плотность тумана [0.0 0.5 1.0 1.5 2.0]
#define VOLUMETRIC_STRENGTH 1.0 // Сила объёмного света [0.5 0.75 1.0 1.5 2.0]
#define SKY_SATURATION 1.0    // Насыщенность неба [0.7 1.0 1.3 1.6]

//=== НОЧЬ ===
#define AURORA_BRIGHTNESS 1.0 // Яркость авроры [0.5 0.75 1.0 1.5 2.0]
#define STAR_BRIGHTNESS 1.0   // Яркость звёзд [0.5 0.75 1.0 1.5 2.0]
#define MOON_LIGHT 1.0        // Сила лунного света [0.5 0.75 1.0 1.5]

//=== ХУДОЖЕСТВЕННЫЕ ЦВЕТА ОСВЕЩЕНИЯ ===
#define SUN_TINT_R 1.00
#define SUN_TINT_G 0.91
#define SUN_TINT_B 0.78
#define SKY_AMBIENT_R 0.42
#define SKY_AMBIENT_G 0.56
#define SKY_AMBIENT_B 0.85

//================================================================
// Автоматические параметры качества (не трогать вручную)
//================================================================
#if SHADER_QUALITY == ULTRA
    #define WATER_OCTAVES    4
    #define AURORA_OCTAVES   6
    #define CLOUD_OCTAVES    5
    #define SSAO_SAMPLES    16
    #define GODRAYS_SAMPLES 64
    #define SPEC_POWER      130.0
    #define BLOOM_BASE      0.28
    #define FRESNEL_POWER   3.0
    #define SHADOW_SAMPLES  4
    #define PCSS_SAMPLES    16
    #define SHADOWMAP_RES   4096.0
    #define SOFT_SHADOWS    1
    #define CLOUD_MARCH     1
#elif SHADER_QUALITY == SUPER_HIGH
    #define WATER_OCTAVES    3
    #define AURORA_OCTAVES   5
    #define CLOUD_OCTAVES    4
    #define SSAO_SAMPLES    10
    #define GODRAYS_SAMPLES 44
    #define SPEC_POWER      90.0
    #define BLOOM_BASE      0.22
    #define FRESNEL_POWER   3.5
    #define SHADOW_SAMPLES  2
    #define PCSS_SAMPLES    9
    #define SHADOWMAP_RES   2048.0
    #define SOFT_SHADOWS    1
    #define CLOUD_MARCH     1
#elif SHADER_QUALITY == HIGH
    #define WATER_OCTAVES    2
    #define AURORA_OCTAVES   4
    #define CLOUD_OCTAVES    3
    #define SSAO_SAMPLES     6
    #define GODRAYS_SAMPLES 28
    #define SPEC_POWER      60.0
    #define BLOOM_BASE      0.17
    #define FRESNEL_POWER   4.0
    #define SHADOW_SAMPLES  4
    #define PCSS_SAMPLES    6
    #define SHADOWMAP_RES   1536.0
    #define SOFT_SHADOWS    1
    #define CLOUD_MARCH     0
#else // LOW
    #define WATER_OCTAVES    1
    #define AURORA_OCTAVES   2
    #define CLOUD_OCTAVES    2
    #define SSAO_SAMPLES     4
    #define GODRAYS_SAMPLES 16
    #define SPEC_POWER      25.0
    #define BLOOM_BASE      0.10
    #define FRESNEL_POWER   5.0
    #define SHADOW_SAMPLES  1
    #define PCSS_SAMPLES    1
    #define SHADOWMAP_RES   1024.0
    #define SOFT_SHADOWS    0
    #define CLOUD_MARCH     0
#endif

#define BLOOM_STRENGTH (BLOOM_BASE)
