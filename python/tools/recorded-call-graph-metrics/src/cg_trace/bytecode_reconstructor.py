import dataclasses
import dis
import logging
from dis import Instruction
from types import FrameType
from typing import List

LOGGER = logging.getLogger(__name__)

# See https://docs.python.org/3/library/dis.html#python-bytecode-instructions for
# details on the bytecode instructions

# TODO: read https://opensource.com/article/18/4/introduction-python-bytecode


class BytecodeExpr:
    """An expression reconstructed from Python bytecode
    """


@dataclasses.dataclass(frozen=True, eq=True, order=True)
class BytecodeVariableName(BytecodeExpr):
    name: str

    def __str__(self):
        return self.name


@dataclasses.dataclass(frozen=True, eq=True, order=True)
class BytecodeAttribute(BytecodeExpr):
    attr_name: str
    object: BytecodeExpr

    def __str__(self):
        return f"{self.object}.{self.attr_name}"


@dataclasses.dataclass(frozen=True, eq=True, order=True)
class BytecodeCall(BytecodeExpr):
    function: BytecodeExpr

    def __str__(self):
        return f"{self.function}()"


@dataclasses.dataclass(frozen=True, eq=True, order=True)
class BytecodeUnknown(BytecodeExpr):
    opname: str

    def __str__(self):
        return f"<{self.opname}>"


def find_inst_that_added_elem_to_stack(
    instructions: List[Instruction], start_index: int, stack_pos: int
):
    """Backwards traverse instructions

    Backwards traverse the instructions starting at `start_index` until we find the
    instruction that added the element at stack position `stack_pos` (where 0 means top
    of stack). For example, if the instructions are:

    ```
    0: LOAD_GLOBAL              0 (func)
    1: LOAD_CONST               1 (42)
    2: CALL_FUNCTION            1
    ```

    We can look for the function that is called by invoking this function with
    `start_index = 1` and `stack_pos = 1`. It will see that `LOAD_CONST` added the top
    element to the stack, and find that `LOAD_GLOBAL` was the instruction to add element
    in stack position 1 to the stack -- so the index 0 is returned.

    It is assumed that if `stack_pos == 0` then the instruction you are looking for is
    the one at `instructions[start_index]`. This might not hold, in case of using `NOP`
    instructions.
    """
    LOGGER.debug(f"find_inst_that_added_elem_to_stack {start_index=} {stack_pos=}")
    assert stack_pos >= 0
    for inst in reversed(instructions[: start_index + 1]):
        if stack_pos == 0:
            LOGGER.debug(f"Found it: {inst}")
            return instructions.index(inst)
        LOGGER.debug(f"Skipping {inst}")
        stack_pos -= dis.stack_effect(inst.opcode, inst.arg)

    raise Exception("inst_index_for_stack_diff failed")


def expr_from_instruction(instructions: List[Instruction], index: int) -> BytecodeExpr:
    inst = instructions[index]

    LOGGER.debug(f"expr_from_instruction: {inst} {index=}")

    if inst.opname in ["LOAD_GLOBAL", "LOAD_FAST", "LOAD_NAME"]:
        return BytecodeVariableName(inst.argval)

    # https://docs.python.org/3/library/dis.html#opcode-LOAD_METHOD
    # https://docs.python.org/3/library/dis.html#opcode-LOAD_ATTR
    elif inst.opname in ["LOAD_METHOD", "LOAD_ATTR"]:
        attr_name = inst.argval
        obj_index = find_inst_that_added_elem_to_stack(instructions, index - 1, 0)
        obj_expr = expr_from_instruction(instructions, obj_index)
        return BytecodeAttribute(attr_name=attr_name, object=obj_expr)

    # https://docs.python.org/3/library/dis.html#opcode-CALL_FUNCTION
    elif inst.opname in ["CALL_FUNCTION", "CALL_METHOD", "CALL_FUNCTION_KW"]:
        assert index > 0
        assert isinstance(inst.arg, int)
        if inst.opname in ["CALL_FUNCTION", "CALL_METHOD"]:
            num_stack_elems = inst.arg
        elif inst.opname == "CALL_FUNCTION_KW":
            num_stack_elems = inst.arg + 1

        func_index = find_inst_that_added_elem_to_stack(
            instructions, index - 1, num_stack_elems
        )
        func_expr = expr_from_instruction(instructions, func_index)
        return BytecodeCall(function=func_expr)

    else:
        # LOAD_BUILD_CLASS is included here intentionally for now, since I don't really
        # know what to do about it.
        LOGGER.warning(f"Don't know how to handle this type of instruction: {inst}")
        return BytecodeUnknown(inst.opname)


def expr_from_frame(frame: FrameType) -> BytecodeExpr:
    bytecode = dis.Bytecode(frame.f_code, current_offset=frame.f_lasti)

    LOGGER.debug(f"bytecode: \n{bytecode.dis()}")

    instructions = list(iter(bytecode))
    last_instruction_index = [inst.offset for inst in instructions].index(frame.f_lasti)
    return expr_from_instruction(instructions, last_instruction_index)
