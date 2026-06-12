using Godot;
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
struct ComputeBoid3D
{
    public Vector3 Position;
    private float _pad1;
    public Vector3 Direction;
    private float _pad2;
    public Vector3 GroupHeading;
    private float _pad3;
    public Vector3 GroupCenter;
    private float _pad4;
    public Vector3 SeparationHeading;
    public int Neighbors;
}

struct Boid3D
{
    public Vector3 Position;
    public Vector3 Direction;
    public Vector3 Velocity;
    public Rid Rid;
}

public partial class BoidFlock3d : Node3D
{
    [Export]
    public int boidCount { get; set; } = 10;

    [Export]
    private float influenceRadius = 6.0f;

    [Export]
    /// 45 default
    private float avoidanceRadius2 = 3.0f;

    [Export]
    public float cohesionWeight = 1.85f;

    [Export]
    public float separationWeight = 2.6f;

    [Export]
    public float alignmentWeight = 1.65f;

    [Export]
    public float maxSteerForce { get; set; } = 3.0f;

    [Export]
    public Vector2 speedLimit { get; set; } = new Vector2(3.0f, 5.0f);

    public Vector3 worldDim { get; set; } = Vector3.Zero;

    private Boid3D[] boids = null;
    private ComputeBoid3D[] computeBoids = null;
    private byte[] backingBuffer = null;
    private byte[] pushConstant = null;
    private Rid rdbuffer;
    private Rid uniformSet;

    private RenderingDevice rd;
    private Rid shader;
    private Rid pipeline;

    [Export]
    private Mesh mesh;

    private Rid tracker;
    [Export]
    private Mesh trackerMesh;

    public override void _Ready()
    {
        SetProcess(false);

        rd = RenderingServer.CreateLocalRenderingDevice();
        var shaderSource = new RDShaderSource();
        shaderSource.Language = RenderingDevice.ShaderLanguage.Glsl;
        var srcString = FileAccess.GetFileAsString("res://Src/boid_flock_3d.comp.glsl");
        shaderSource.SourceCompute = srcString;
        var spirv = rd.ShaderCompileSpirVFromSource(shaderSource);

        shader = rd.ShaderCreateFromSpirV(spirv);
        pipeline = rd.ComputePipelineCreate(shader);

        tracker = RenderingServer.InstanceCreate2(trackerMesh.GetRid(), GetWorld3D().Scenario);
    }

    public override void _Process(double delta)
    {
        var span = MemoryMarshal.Cast<byte, ComputeBoid3D>(backingBuffer);
        for (int i = 0; i < boidCount; i++)
        {
            computeBoids[i].Position = boids[i].Position;
            computeBoids[i].Direction = boids[i].Direction;
            span[i] = computeBoids[i];
        }

        rd.BufferUpdate(rdbuffer, 0, (uint)backingBuffer.Length, backingBuffer);


        long computeList = rd.ComputeListBegin();
        rd.ComputeListBindComputePipeline(computeList, pipeline);
        rd.ComputeListBindUniformSet(computeList, uniformSet, 0);
        rd.ComputeListSetPushConstant(computeList, pushConstant, (uint)pushConstant.Length);
        rd.ComputeListDispatch(computeList, (uint)boidCount, 1, 1);
        rd.ComputeListEnd();

        rd.Submit();
        rd.Sync();

        var result = rd.BufferGetData(rdbuffer);
        var updatedBoids = MemoryMarshal.Cast<byte, ComputeBoid3D>(result);
        GD.PrintS(
            "from shader:",
            updatedBoids[1].Position,
            "from c#:",
            updatedBoids[0].GroupHeading
        );

        for (int i = 0; i < boidCount; i++)
        {
            var acceleration = Vector3.Zero;

            ref var boid = ref boids[i];
            var updated = updatedBoids[i];
            var neighborCount = updated.Neighbors;
            if (neighborCount > 0)
            {
                var centerAvg = updated.GroupCenter /= neighborCount;
                var offsetToCenter = centerAvg - boid.Position;
                acceleration += SteerTowards(offsetToCenter, boid.Velocity) * cohesionWeight;
                acceleration += SteerTowards(updated.SeparationHeading, boid.Velocity) * separationWeight;
                acceleration += SteerTowards(updated.GroupHeading, boid.Velocity) * alignmentWeight;
            }

            boid.Velocity += acceleration * (float)delta;
            var dir = boid.Velocity.Normalized();
            var speed = boid.Velocity.Length();
            speed = Mathf.Clamp(speed, speedLimit.X, speedLimit.Y);
            boid.Velocity = dir * speed;

            var position = boid.Position + boid.Velocity;
            if (position.X < (-worldDim.X / 2))
            {
                position = position with { X = worldDim.X / 2 };
            }
            else if (position.X > worldDim.X / 2)
            {
                position = position with { X = -worldDim.X / 2 };
            }
            if (position.Y < worldDim.Y)
            {
                position = position with { Y = worldDim.X };
            }
            else if (position.Y > 14f)
            {
                position = position with { Y = worldDim.Y };
            }
            if (position.Z < (-worldDim.Z / 2))
            {
                position = position with { Z = worldDim.Z / 2 };
            }
            else if (position.Z > worldDim.Z / 2)
            {
                position = position with { Z = -worldDim.Z / 2 };
            }

            boid.Position = position;
            boid.Direction = dir;
            // maybe use direction to make quaternion?
            // boid.Rotation = boid.Velocity.Angle();

            // RenderingServer.CanvasItemSetTransform(boid.Rid, new Transform2D(boid.Rotation, boid.Position));
            var transform = new Transform3D(
                    Basis.Identity,
                    boid.Position
            );
            RenderingServer.InstanceSetTransform(boid.Rid, transform);
            if (i == 0)
                RenderingServer.InstanceSetTransform(tracker, transform);
        }
    }

    public override void _Notification(int what)
    {
        if ((long)what == NotificationExitTree)
        {
            Cleanup();
        }
    }

    private Vector3 SteerTowards(Vector3 towards, Vector3 velocity)
    {
        var v = towards.Normalized() * speedLimit.Y - velocity;
        var clamped = v.Normalized() * Mathf.Min(v.Length(), maxSteerForce);
        return clamped;
    }

    public void Setup()
    {
        boids = new Boid3D[boidCount];
        computeBoids = new ComputeBoid3D[boidCount];
        int stride = Marshal.SizeOf<ComputeBoid3D>();
        GD.Print(stride);
        backingBuffer = new byte[stride * boidCount];
        pushConstant = new byte[16];
        Buffer.BlockCopy(BitConverter.GetBytes(avoidanceRadius2), 0, pushConstant, 0, 4);
        Buffer.BlockCopy(BitConverter.GetBytes(influenceRadius * influenceRadius), 0, pushConstant, 4, 4);
        Buffer.BlockCopy(BitConverter.GetBytes(boidCount), 0, pushConstant, 8, 4);

        var scenario = GetWorld3D().Scenario;
        for (int i = 0; i < boids.Length; i++)
        {
            boids[i].Direction = new Vector3(GD.Randf(), GD.Randf(), GD.Randf());
            boids[i].Position = new Vector3((float)GD.RandRange(0f, worldDim.X), (float)GD.RandRange(0f, worldDim.Y), (float)GD.RandRange(0f, worldDim.Z));
            boids[i].Velocity = boids[i].Direction * (float)GD.RandRange(speedLimit.X, speedLimit.Y);
            boids[i].Rid = RenderingServer.InstanceCreate2(mesh.GetRid(), scenario);
        }

        rdbuffer = rd.StorageBufferCreate((uint)backingBuffer.Length, backingBuffer);

        var uniform = new RDUniform();
        uniform.UniformType = RenderingDevice.UniformType.StorageBuffer;
        uniform.Binding = 0;
        uniform.AddId(rdbuffer);

        uniformSet = rd.UniformSetCreate(
            new Godot.Collections.Array<RDUniform> { uniform },
            shader,
            0
        );

    }

    private void Cleanup()
    {
        foreach (var boid in boids)
        {
            RenderingServer.FreeRid(boid.Rid);
        }
        mesh.Free();
        rd.FreeRid(uniformSet);
        rd.FreeRid(rdbuffer);
        rd.FreeRid(shader);
        rd.Free();
    }
}
