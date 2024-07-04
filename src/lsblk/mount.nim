import std/[streams, strscans]
import results

type Mount* = object of RootObj
  device*: string
  mountpoint*: string
  fstype*: string
  mountopts*: string


proc notSpace(input: string, match: var string, start: int): int =
  result = 0
  while input[start+result] != ' ': inc result
  match = input[start..start+result-1]

proc getMounts*(): Result[seq[Mount], string] =
  var res: seq[Mount] = @[]
  var fdmounts = newFileStream("/proc/mounts")
  if fdmounts == nil:
    # cannot open file
    return ok seq[Mount](@[])
  defer: fdmounts.close()
  var linenum = 0
  var line, dev, mp, fstype, mountopts: string
  while fdmounts.readLine line:
    inc linenum
    if scanf(line, "${notSpace} ${notSpace} ${notSpace} ${notSpace} 0 0$.", dev, mp, fstype, mountopts):
      res.add Mount(device: dev, mountpoint: mp, fstype: fstype, mountopts: mountopts)
    else:
      return err "Fail to parse /proc/mounts:" & $linenum & " : " & line
  ok res

## List out all found block devices and populate all fields.
proc listMounts*(): Result[seq[Mount], string] =
  getMounts()
