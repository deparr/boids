using Godot;

public partial class World2d : Node2D
{
    [Export]
    private BoidFlock2d flock;

    private Label fpsLabel;

    public override void _Ready()
    {
        var cohesionSlider = GetNode<HSlider>("%CohesionSlider");
        cohesionSlider.SetValueNoSignal(flock.cohesionWeight);
        cohesionSlider.ValueChanged += (value) => flock.cohesionWeight = (float)value;

        var separationSlider = GetNode<HSlider>("%SeparationSlider");
        separationSlider.SetValueNoSignal(flock.separationWeight);
        separationSlider.ValueChanged += (value) => flock.separationWeight = (float)value;

        var alignmentSlider = GetNode<HSlider>("%AlignmentSlider");
        alignmentSlider.SetValueNoSignal(flock.alignmentWeight);
        alignmentSlider.ValueChanged += (value) => flock.alignmentWeight = (float)value;

        var flockSize = GetNode<SpinBox>("%FlockSizeSpinBox");
        flockSize.SetValueNoSignal(flock.boidCount);
        flockSize.ValueChanged += (value) => flock.ResizeFlock(Mathf.RoundToInt(value));
        flockSize.Editable = true;

        fpsLabel = GetNode<Label>("%FPS");
        GetViewport().SizeChanged += HandleWindowResize;
        HandleWindowResize();
        flock.Setup();
        flock.SetProcess(true);
    }

    public override void _Process(double delta)
    {
        fpsLabel.Text = $"{Engine.GetFramesPerSecond():F0} fps";
    }

    private void HandleWindowResize()
    {
        var size = GetViewport().GetVisibleRect().Size;
        flock.worldDim = size;
    }
}
