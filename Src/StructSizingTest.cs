using Godot;
using System.Runtime.InteropServices;

namespace StructSize;

[StructLayout(LayoutKind.Sequential)]
struct SizeTest
{
    public Vector3 one; // each of these is 16 bytes in gpu land
    private float pad; // so we add padding between vec3 elements
    public Vector3 two;
    private float pad2; // struct need to be multiple of 16, a float gets us to 32

    public override string ToString()
    {
        return $"{{ {one} {two} }}";
    }
}

[StructLayout(LayoutKind.Sequential)]
struct SizeTest2
{
    public Vector3 a;
    public Vector3 b;
    public int c;
}

public partial class StructSizingTest : Control
{
    [Export(PropertyHint.MultilineText)]
    public string shaderSource;
    private RenderingDevice rd;
    private Rid shader;
    private Rid pipeline;
    private Rid rdbuffer;
    private Rid uniformSet;
    private byte[] buffer;

    public override void _Ready()
    {
        rd = RenderingServer.CreateLocalRenderingDevice();
        var sh = new RDShaderSource();
        sh.Language = RenderingDevice.ShaderLanguage.Glsl;
        sh.SourceCompute = shaderSource;
        var spirv = rd.ShaderCompileSpirVFromSource(sh);

        shader = rd.ShaderCreateFromSpirV(spirv);
        pipeline = rd.ComputePipelineCreate(shader);

        buffer = new byte[Marshal.SizeOf<SizeTest>() * 2];
        rdbuffer = rd.StorageBufferCreate((uint)buffer.Length, buffer);

        GetNode<Label>("%SizeTestSize").Text = $"C# sizeof(SizeTest): {Marshal.SizeOf<SizeTest>()}";
        GetNode<Label>("%SizeTest2Size").Text = $"C# sizeof(SizeTest2): {Marshal.SizeOf<SizeTest2>()}";

        GetNode<Button>("%Submit").Pressed += Dispatch;
    }

    public override void _ExitTree()
    {
        rd.FreeRid(uniformSet);
        rd.FreeRid(rdbuffer);
        rd.FreeRid(shader);
        rd.Free();
    }

    public void Dispatch()
    {
        var btn = GetNode<Button>("%Submit");
        btn.Disabled = true;
        var one = GetNode<LineEdit>("%One").Text;
        var two = GetNode<LineEdit>("%Two").Text;
        var ones = one.SplitFloats(",", false);
        var twos = two.SplitFloats(",", false);
        var sizetest = new SizeTest();
        sizetest.one = new Vector3(ones[0], ones[1], ones[2]);
        sizetest.two = new Vector3(twos[0], twos[1], twos[2]);

        var span = MemoryMarshal.Cast<byte, SizeTest>(buffer);
        span[0] = sizetest;
        GD.PrintS("before:", sizetest);
        sizetest.one = new Vector3(ones[3], ones[4], ones[5]);
        sizetest.two = new Vector3(twos[3], twos[4], twos[5]);
        span[1] = sizetest;
        GD.PrintS("before:", sizetest);

        var err = rd.BufferUpdate(rdbuffer, 0, (uint)buffer.Length, buffer);
        if (err != Error.Ok)
        {
            GD.Print(err.ToString());
            return;
        }


        var uniform = new RDUniform();
        uniform.UniformType = RenderingDevice.UniformType.StorageBuffer;
        uniform.Binding = 0;
        uniform.AddId(rdbuffer);

        Rid uniformSet = rd.UniformSetCreate(
            new Godot.Collections.Array<RDUniform> { uniform },
            shader,
            0
        );

        long computeList = rd.ComputeListBegin();
        rd.ComputeListBindComputePipeline(computeList, pipeline);
        rd.ComputeListBindUniformSet(computeList, uniformSet, 0);
        rd.ComputeListDispatch(computeList, 1, 1, 1);
        rd.ComputeListEnd();

        rd.Submit();
        rd.Sync();

        var result = rd.BufferGetData(rdbuffer);
        var st = MemoryMarshal.Cast<byte, SizeTest>(result);
        GD.PrintS("after:", st[0], st[1]);

        btn.Disabled = false;
    }
}
