using Godot;
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
struct ComputeBoid
{
    public Vector2 Position;
    public Vector2 Direction;
    public Vector2 GroupHeading;
    public Vector2 GroupCenter;
    public Vector2 SeparationHeading;
    public int Neigbors;
    public int _pad;
};

public partial class BoidFlock2dCompute : Node2D
{
    [Export]
    public int boidCount { get; set; } = 10;

    [Export]
    private Color[] colors = new Color[] { Color.Color8(0xff, 0xe3, 0x04) };

    [Export]
    private Vector2[] polygonPoints;

    [Export]
    private float influenceRadius = 120.0f;

    [Export]
    private float viewAngle = 135f;

    [Export]
    /// 45 default
    private float avoidanceRadius2 = 2025.0f;

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

    private Boid[] boids = null;
    private ComputeBoid[] computeBoids = null;
    private byte[] backingBuffer = null;
    private byte[] pushConstantBytes = null;
    private Rid rdbuffer;
    private Rid uniformSet;

    public Vector2 worldDim { get; set; } = Vector2.Zero;

    private RenderingDevice rd;
    private Rid shader;
    private Rid pipeline;


    public override void _Ready()
    {
        SetProcess(false);

        if (polygonPoints.Length < 3)
        {
            GD.PushError("boidflock: polygonPoints has < 3 points");
            return;
        }
        rd = RenderingServer.CreateLocalRenderingDevice();

        var shaderSource = new RDShaderSource();
        shaderSource.Language = RenderingDevice.ShaderLanguage.Glsl;
        var srcString = FileAccess.GetFileAsString("res://Src/boid_flock.comp.glsl");
        shaderSource.SourceCompute = srcString;
        var spirv = rd.ShaderCompileSpirVFromSource(shaderSource);

        shader = rd.ShaderCreateFromSpirV(spirv);
        pipeline = rd.ComputePipelineCreate(shader);
    }

    public override void _Process(double delta)
    {
        // copy back into compute buffer
        var span = MemoryMarshal.Cast<byte, ComputeBoid>(backingBuffer);
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
        rd.ComputeListSetPushConstant(computeList, pushConstantBytes, (uint)pushConstantBytes.Length);
        rd.ComputeListDispatch(computeList, 4, 1, 1);
        rd.ComputeListEnd();

        rd.Submit();
        rd.Sync();

        var result = rd.BufferGetData(rdbuffer);
        var updatedBoids = MemoryMarshal.Cast<byte, ComputeBoid>(result);

        for (int i = 0; i < boidCount; i++)
        {
            var acceleration = Vector2.Zero;

            ref var boid = ref boids[i];
            var updated = updatedBoids[i];
            var neighborCount = updated.Neigbors;
            if (neighborCount > 0)
            {
                var centerAvg = updated.GroupCenter / neighborCount;
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
            if (position.X < -5.0)
            {
                position = position with { X = worldDim.X };
            }
            else if (position.X > worldDim.X + 5f)
            {
                position = position with { X = 0.0f };
            }
            else if (position.Y < -5.0)
            {
                position = position with { Y = worldDim.Y };
            }
            else if (position.Y > worldDim.Y + 5f)
            {
                position = position with { Y = 0.0f };
            }

            boid.Position = position;
            boid.Direction = dir;
            boid.Rotation = boid.Velocity.Angle();

            RenderingServer.CanvasItemSetTransform(boid.Rid, new Transform2D(boid.Rotation, boid.Position));
        }
    }

    public override void _Notification(int what)
    {
        if ((long)what == NotificationExitTree)
        {
            Cleanup();
        }
    }

    private Vector2 SteerTowards(Vector2 towards, Vector2 velocity)
    {
        var v = towards.Normalized() * speedLimit.Y - velocity;
        var clamped = v.Normalized() * Mathf.Min(v.Length(), maxSteerForce);
        return clamped;

    }

    public void Setup()
    {
        boids = new Boid[boidCount];
        computeBoids = new ComputeBoid[boidCount];
        int stride = Marshal.SizeOf<ComputeBoid>();
        backingBuffer = new byte[stride * boidCount];
        pushConstantBytes = new byte[16];
        Buffer.BlockCopy(BitConverter.GetBytes(avoidanceRadius2), 0, pushConstantBytes, 0, 4);
        Buffer.BlockCopy(BitConverter.GetBytes(influenceRadius * influenceRadius), 0, pushConstantBytes, 4, 4);
        Buffer.BlockCopy(BitConverter.GetBytes(boidCount), 0, pushConstantBytes, 8, 4);

        for (int i = 0; i < boids.Length; i++)
        {
            boids[i].Color = colors[i % colors.Length];
            boids[i].Direction = Vector2.FromAngle((float)GD.RandRange(0.0, Mathf.Tau));
            boids[i].Position = new Vector2((float)GD.RandRange(0f, worldDim.X), (float)GD.RandRange(0f, worldDim.Y));
            boids[i].Velocity = boids[i].Direction * (float)GD.RandRange(speedLimit.X, speedLimit.Y);
            var rid = RenderingServer.CanvasItemCreate();
            RenderingServer.CanvasItemAddPolygon(rid, polygonPoints, new Color[] { boids[i].Color });
            RenderingServer.CanvasItemSetParent(rid, GetCanvasItem());
            boids[i].Rid = rid;
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
        rd.FreeRid(uniformSet);
        rd.FreeRid(rdbuffer);
        rd.FreeRid(shader);
        rd.Free();
    }
}

