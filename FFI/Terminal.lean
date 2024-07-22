import Alloy.C

open scoped Alloy.C

namespace Terminal

alloy c include <lean/lean.h>
alloy c extern def myAdd (x y : UInt32) : UInt32 := {
  return x + y;
}

end Terminal
