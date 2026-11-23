import Blanc.Lift.Stock.Cert

/-!
# The bytes the proofs are about

Prints `Blanc.Lift.Stock.code`, the runtime every Stock theorem names in its `F.sevm.code = code`
premise, as one line of lowercase hex. `check.sh` hashes it and compares it with the code
Robinhood Chain returns for the implementation address.
-/

def hexByte (b : UInt8) : String :=
  let d := Nat.toDigits 16 b.toNat
  (if d.length < 2 then '0' :: d else d).foldl String.push ""

#eval IO.println ("0x" ++ String.join (Blanc.Lift.Stock.code.data.toList.map hexByte))
