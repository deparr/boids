using Godot;

public partial class World3d : Node3D
{
    [Export]
    private BoidFlock3d flock;

    public override void _Ready()
    {
        GetNode<Camera3D>("Camera3D").LookAt(flock.Position - Vector3.Right, Vector3.Up);
        flock.Setup();
        flock.worldDim = new Vector3(40, 14, 40);
        flock.SetProcess(true);
    }
}
