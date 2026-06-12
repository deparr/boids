#version 450

layout(local_size_x = 512, local_size_y = 1, local_size_z = 1) in;

struct Boid {
    vec2 position;
    vec2 direction;
    vec2 group_heading;
    vec2 group_center;
    vec2 separation_heading;
    int  neighbors;
    int _pad;
};

layout(set = 0, binding = 0, std430) restrict buffer BoidBuffer {
    Boid items[];
} boids;

layout(push_constant, std430) uniform Params {
    float avoidanceRadius2;
    float influenceRadius2;
    int boidCount;
    float _;
} params;

void main() {
    uint i = gl_GlobalInvocationID.x;
    boids.items[i].group_heading = vec2(0.);
    boids.items[i].group_center = vec2(0.);
    boids.items[i].separation_heading = vec2(0.);
    boids.items[i].neighbors = 0;
    for (int j = 0; j < params.boidCount; j++) {
        if (j == i) continue;
        Boid boidB = boids.items[j];
        vec2 offset = boidB.position - boids.items[i].position;
        float sqr_dist = dot(offset, offset);

        if (sqr_dist < params.influenceRadius2) {
            boids.items[i].neighbors += 1;
            boids.items[i].group_heading += boidB.direction;
            boids.items[i].group_center += boidB.position;

            if (sqr_dist < params.avoidanceRadius2) {
                boids.items[i].separation_heading -= offset / sqr_dist;
            }
        }

    }
}
