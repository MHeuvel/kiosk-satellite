#version 460 core
#define CLOUD_STEPS 40
#define CLOUD_LOW_NOISE
// Shared cloud lighting keeps dawn/dusk warmth near the low sun.
#include "weather_mood_clouds.glsl"
