import dataclasses
import dis
import logging
from dis import Instruction
from types import FrameType
from typing import Any, List

LOGGER = logging.getLogger(__name__)

# See https://docs.python.org/3/library/dis.html#python-bytecode-instructions for
# details on the bytecode instructions

# TODO: read https://opensource.com/article/18/4/introduction-python-bytecode


class BytecodeExpr:
    """An expression reconstructed from Python bytecode
    """


@dataclasses.dataclass(frozen=True, eq=True, order=True)
class BytecodeConst(BytecodeExpr):
    """FOR LOAD_CONST"""

    value: Any

    def __str__(self):
        return repr(self.value)


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
class BytecodeSubscript(BytecodeExpr):
    key: BytecodeExpr
    object: BytecodeExpr

    def __str__(self):
        return f"{self.object}[{self.key}]"


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


@dataclasses.dataclass(frozen=True, eq=True, order=True)
class BytecodeMakeFunction(BytecodeExpr):
    """For MAKE_FUNCTION opcode"""

    qualified_name: BytecodeExpr

    def __str__(self):
        return f"<MAKE_FUNCTION>(qualified_name={self.qualified_name})>"


@dataclasses.dataclass(frozen=True, eq=True, order=True)
class SomethingInvolvingScaryBytecodeJump(BytecodeExpr):
    opname: str

    def __str__(self):
        return "<SomethingInvolvingScaryBytecodeJump>"


def expr_that_added_elem_to_stack(
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
    in stack position 1 to the stack -- so `expr_from_instruction(instructions, 0)` is
    returned.

    It is assumed that if `stack_pos == 0` then the instruction you are looking for is
    the one at `instructions[start_index]`. This might not hold, in case of using `NOP`
    instructions.

    If any jump instruction is found, `SomethingInvolvingScaryBytecodeJump` is returned
    immediately. (since correctly process the bytecode when faced with jumps is not as
    straight forward).
    """
    LOGGER.debug(f"find_inst_that_added_elem_to_stack {start_index=} {stack_pos=}")
    assert stack_pos >= 0
    for inst in reversed(instructions[: start_index + 1]):
        # Return immediately if faced with a jump
        if inst.opcode in dis.hasjabs or inst.opcode in dis.hasjrel:
            return SomethingInvolvingScaryBytecodeJump(inst.opname)

        if stack_pos == 0:
            LOGGER.debug(f"Found it: {inst}")
            found_index = instructions.index(inst)
            break
        old = stack_pos
        stack_pos -= dis.stack_effect(inst.opcode, inst.arg)
        new = stack_pos
        LOGGER.debug(f"Skipping ({old} -> {new}) {inst}")
    else:
        raise Exception("inst_index_for_stack_diff failed")

    return expr_from_instruction(instructions, found_index)


def expr_from_instruction(instructions: List[Instruction], index: int) -> BytecodeExpr:
    inst = instructions[index]

    LOGGER.debug(f"expr_from_instruction: {inst} {index=}")

    if inst.opname in ["LOAD_GLOBAL", "LOAD_FAST", "LOAD_NAME", "LOAD_DEREF"]:
        return BytecodeVariableName(inst.argval)

    elif inst.opname in ["LOAD_CONST"]:
        return BytecodeConst(inst.argval)

    # https://docs.python.org/3/library/dis.html#opcode-LOAD_METHOD
    # https://docs.python.org/3/library/dis.html#opcode-LOAD_ATTR
    elif inst.opname in ["LOAD_METHOD", "LOAD_ATTR"]:
        attr_name = inst.argval
        obj_expr = expr_that_added_elem_to_stack(instructions, index - 1, 0)
        return BytecodeAttribute(attr_name=attr_name, object=obj_expr)

    elif inst.opname in ["BINARY_SUBSCR"]:
        key_expr = expr_that_added_elem_to_stack(instructions, index - 1, 0)
        obj_expr = expr_that_added_elem_to_stack(instructions, index - 1, 1)
        return BytecodeSubscript(key=key_expr, object=obj_expr)

    # https://docs.python.org/3/library/dis.html#opcode-CALL_FUNCTION
    elif inst.opname in ["CALL_FUNCTION", "CALL_METHOD", "CALL_FUNCTION_KW"]:
        assert index > 0
        assert isinstance(inst.arg, int)
        if inst.opname in ["CALL_FUNCTION", "CALL_METHOD"]:
            num_stack_elems = inst.arg
        elif inst.opname == "CALL_FUNCTION_KW":
            num_stack_elems = inst.arg + 1

        func_expr = expr_that_added_elem_to_stack(
            instructions, index - 1, num_stack_elems
        )
        return BytecodeCall(function=func_expr)

    elif inst.opname in ["MAKE_FUNCTION"]:
        name_expr = expr_that_added_elem_to_stack(instructions, index - 1, 0)
        assert isinstance(name_expr, BytecodeConst)
        return BytecodeMakeFunction(qualified_name=name_expr)

    # TODO: handle with statements (https://docs.python.org/3/library/dis.html#opcode-SETUP_WITH)
    WITH_OPNAMES = ["SETUP_WITH", "WITH_CLEANUP_START", "WITH_CLEANUP_FINISH"]

    # Special cases ignored for now:
    #
    # - LOAD_BUILD_CLASS: Called when constructing a class.
    # - IMPORT_NAME: Observed to result in a call to filename='<frozen
    #   importlib._bootstrap>', linenum=389, funcname='parent'
    if inst.opname not in ["LOAD_BUILD_CLASS", "IMPORT_NAME"] + WITH_OPNAMES:
        LOGGER.warning(f"Don't know how to handle this type of instruction: {inst}")
        # Uncomment to stop execution when encountering non-ignored unknown instruction
        # class MyBytecodeException(BaseException):
        #     pass
        #
        # raise MyBytecodeException()
    return BytecodeUnknown(inst.opname)


def expr_from_frame(frame: FrameType) -> BytecodeExpr:
    bytecode = dis.Bytecode(frame.f_code, current_offset=frame.f_lasti)

    LOGGER.debug(
        f"{frame.f_code.co_filename}:{frame.f_lineno}: bytecode: \n{bytecode.dis()}"
    )

    instructions = list(iter(bytecode))
    last_instruction_index = [inst.offset for inst in instructions].index(frame.f_lasti)
    return expr_from_instruction(instructions, last_instruction_index)
