using Godot;

public partial class Main : Control
{

    [Export]
    private PackedScene gdScriptScene;

    [Export]
    private PackedScene cSharpScene;

    [Export]
    private PackedScene computeScene;

    private Node worldAnchor;

    private Label fpsCounter;

    private Control menu;

    public override void _Ready()
    {
        GetNode<Button>("%GDScript").Pressed += LoadGDScript;
        GetNode<Button>("%C#").Pressed += LoadCSScript;
        GetNode<Button>("%Compute").Pressed += LoadCompute;
        GetNode<Button>("%Quit").Pressed += Quit;

        menu = GetNode<Control>("%Menu");
        worldAnchor = GetNode<Node>("WorldAnchor");
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is InputEventKey keyev)
        {
            if (!keyev.Pressed && keyev.Keycode == Key.Escape)
            {
                if (!menu.Visible)
                {
                    menu.Visible = true;
                    SwapScene(null);
                }
            }
        }
    }

    private void SwapScene(PackedScene scene)
    {
        var oldFlock = worldAnchor.GetChildOrNull<Node2D>(0);
        if (oldFlock != null)
        {
            worldAnchor.RemoveChild(oldFlock);
            oldFlock.QueueFree();
        }
        if (scene != null)
        {
            menu.Visible = false;
            var newFlock = scene.Instantiate();
            worldAnchor.AddChild(newFlock);
        }
    }

    public void LoadGDScript()
    {
        SwapScene(gdScriptScene);
    }

    public void LoadCSScript()
    {
        SwapScene(cSharpScene);
    }

    public void LoadCompute()
    {
        SwapScene(computeScene);
    }

    public void Quit()
    {
        GetTree().Notification((int)NotificationWMCloseRequest);
    }
}
