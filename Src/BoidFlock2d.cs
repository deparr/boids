using Godot;

struct Boid
{
    public Vector2 Position;
    public Vector2 Direction;
    public Vector2 Velocity;
    public float Rotation;
    public Color Color;
    public Rid Rid;
};

public partial class BoidFlock2d : Node2D
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
    public float cohesionWeight  = 1.85f;
    [Export]
    public float separationWeight  = 2.6f;
    [Export]
    public float alignmentWeight  = 1.65f;

    [Export]
    public float maxSteerForce { get; set; } = 3.0f;

    [Export]
    public Vector2 speedLimit { get; set; } = new Vector2(3.0f, 5.0f);

    private Boid[] boids = null;

    public Vector2 worldDim { get; set; } = Vector2.Zero;

    public override void _Ready()
    {

        if (polygonPoints.Length < 3)
        {
            GD.PushError("boidflock: polygonPoints has < 3 points");
            return;
        }
        SetProcess(false);
    }

    public override void _Process(double delta)
    {
        var deltaFloat = (float)delta;
        for (int i = 0; i < boids.Length; i++)
        {
            ref var boid = ref boids[i];
            var updatedTransform = StepBoid(ref boid, i, deltaFloat);
            RenderingServer.CanvasItemSetTransform(boid.Rid, updatedTransform);
        }
    }

    public override void _Notification(int what)
    {
        if (what == NotificationPredelete)
        {
            CleanUp();
        }
    }

    private Transform2D StepBoid(ref Boid boid, int index, float delta)
    {
        var acceleration = Vector2.Zero;
        var position = boid.Position;

        var groupCenter = Vector2.Zero;
        var groupHeading = Vector2.Zero;
        var groupAvoidanceHeading = Vector2.Zero;
        var neighborCount = 0;
        for (int j = 0; j < boids.Length; j++)
        {
            if (index == j) continue;
            var boid2 = boids[j];
            var distance = boid.Position.DistanceTo(boid2.Position);
            var angle = Mathf.Abs(Mathf.RadToDeg(boid.Position.AngleToPoint(boid2.Position)));
            if (distance > influenceRadius || angle > viewAngle) continue;
            neighborCount += 1;
            groupCenter += boid2.Position;
            groupHeading += boid2.Direction;
            var offset = boid2.Position - boid.Position;
            var sqrDist = offset.X * offset.X + offset.Y + offset.Y;
            if (sqrDist < avoidanceRadius2)
            {
                groupAvoidanceHeading -= offset / sqrDist;
            }

        }


        if (neighborCount > 0)
        {
            groupCenter /= neighborCount;

            var offsetToCenter = groupCenter - boid.Position;
            var cohesionForce = SteerTowards(offsetToCenter, boid.Velocity) * cohesionWeight;
            var separationForce = SteerTowards(groupAvoidanceHeading, boid.Velocity) * separationWeight;
            var alignmentForce = SteerTowards(groupHeading, boid.Velocity) * alignmentWeight;

            acceleration += cohesionForce;
            acceleration += separationForce;
            acceleration += alignmentForce;
        }

        boid.Velocity += acceleration * delta;
        var dir = boid.Velocity.Normalized();
        var speed = boid.Velocity.Length();
        speed = Mathf.Clamp(speed, speedLimit.X, speedLimit.Y);
        boid.Velocity = dir * speed;

        position += boid.Velocity;

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

        return new Transform2D(boid.Rotation, boid.Position);
    }

    private Vector2 SteerTowards(Vector2 towards, Vector2 velocity)
    {
        var v = towards.Normalized() * speedLimit.Y - velocity;
        var clamped = v.Normalized() * Mathf.Min(v.Length(), maxSteerForce);
        return clamped;

    }

    public void ResizeFlock(int newCount)
    {
        SetProcess(false);
        CleanUp();
        boidCount = newCount;
        Setup();
        SetProcess(true);
    }

    public void Setup()
    {
        boids = new Boid[boidCount];

        for (int i = 0; i < boids.Length; i++)
        {
            boids[i].Color = colors[GD.Randi() % colors.Length];
            boids[i].Direction = Vector2.FromAngle((float)GD.RandRange(0.0, Mathf.Tau));
            boids[i].Position = new Vector2((float)GD.RandRange(0f, worldDim.X), (float)GD.RandRange(0f, worldDim.Y));
            boids[i].Velocity = boids[i].Direction * (float)GD.RandRange(speedLimit.X, speedLimit.Y);
            var rid = RenderingServer.CanvasItemCreate();
            RenderingServer.CanvasItemAddPolygon(rid, polygonPoints, new Color[] { boids[i].Color });
            RenderingServer.CanvasItemSetParent(rid, GetCanvasItem());
            boids[i].Rid = rid;
        }
    }

    private void CleanUp()
    {
        foreach (var boid in boids)
        {
            RenderingServer.FreeRid(boid.Rid);
        }
    }
}
