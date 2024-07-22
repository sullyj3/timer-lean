import Alloy.C

open scoped Alloy.C

alloy c include <termios.h> <sys/ioctl.h> <unistd.h> <stdint.h> <lean/lean.h>

namespace Terminal

structure WinSize where
  row : UInt16
  col : UInt16
  xPixel : UInt16
  yPixel : UInt16
  deriving Repr

alloy c section
lean_object * alloc_WinSize() {
  return lean_alloc_ctor(0, 0, 4 * sizeof(uint16_t));
}

lean_object * get_WinSize() {
  lean_object *o = alloc_WinSize();
  struct winsize *w = (struct winsize *)lean_ctor_scalar_cptr(o);
  ioctl(STDOUT_FILENO, TIOCGWINSZ, w);
  return o;
}
end

alloy c extern def getWinSize : IO WinSize := {
  return lean_io_result_mk_ok(get_WinSize())
}

end Terminal
