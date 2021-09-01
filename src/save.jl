
modelproto(;kwargs...) = ModelProto(;
    ir_version=6,
    opset_import=[OperatorSetIdProto(version=11)],
    producer_name="ONNX.jl",
    producer_version=string(Pkg.Types.Context().env.project.version), # TODO: Ugh....
    kwargs...)


"""
    graphproto()
Return an [`ONNX.GraphProto`](@ref) with all fields initialized to empty arrays.
"""
graphproto(;kwargs...) = GraphProto(;
    node = NodeProto[],
    initializer = TensorProto[],
    input = ValueInfoProto[],
    output = ValueInfoProto[],
    value_info = ValueInfoProto[],
    kwargs...
)


add!(gp::GraphProto, np::NodeProto) = push!(gp.node, np)

add!(gp::GraphProto, tp::TensorProto) = push!(gp.initializer, tp)


##############################################################################
#                                 Methods                                    #
##############################################################################

onnx_name(v::Variable) = "x$(v.id)"
onnx_name(op::Ghost.AbstractOp) = "x$(op.id)"


function save_node!(g::GraphProto, op::Ghost.Call)
    save_node!(g, OpConfig{:ONNX, typeof(op.fn)}(), op)
end


function save_node!(g::GraphProto, ::OpConfig{:ONNX, typeof(conv)}, op::Ghost.Call)

    nd = NodeProto(
        input=[onnx_name(v) for v in op.args],
        output=[onnx_name(op)],
        name=onnx_name(op),
        attribute=AttributeProto[],  # TODO
        op_type="Conv"
    )
    push!(g.node, nd)
end


function save_node!(g::GraphProto, ::OpConfig{:ONNX, typeof(add)}, op::Ghost.Call)
    nd = NodeProto(
        input=[onnx_name(v) for v in op.args],
        output=[onnx_name(op)],
        name=onnx_name(op),
        attribute=AttributeProto[],
        op_type="Add"
    )
    push!(g.node, nd)
end



##############################################################################
#                                    API                                     #
##############################################################################

function save(filename::String, tape::Tape{ONNXCtx})
    g = graphproto()
    g.name = "generated_model"
    for op in tape
        @show op
        if op isa Ghost.Input
            @show onnx_name(op)
            add!(g, TensorProto(op.val, onnx_name(op)))
        elseif op isa Ghost.Call
            save_node!(g, op)
        else
            error("$(typeof(op)) is not yet supported in model export")
        end
    end
    res_op = tape[tape.result]
    push!(g.output, ValueInfoProto(onnx_name(res_op), size(res_op.val)))
    m = modelproto();
    m.graph = g;
    open(filename, "w") do io
        writeproto(io, m)
    end
end

