import Foundation
import AppKit
import CoreGraphics
import ImageIO

struct Raster {
 let w: Int; let h: Int; var p: [UInt8]
 init(_ path: String) throws {
  guard let rep = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: path))), rep.bitsPerSample == 8, rep.samplesPerPixel == 4, !rep.isPlanar, let data = rep.bitmapData else { throw Failure("Unsupported PNG \(path)") }
  w = rep.pixelsWide; h = rep.pixelsHigh
  p = (0..<h).flatMap { Array(UnsafeBufferPointer(start: data + $0 * rep.bytesPerRow, count: rep.pixelsWide*4)) }
 }
 init(_ w: Int, _ h: Int) { self.w=w; self.h=h; p=Array(repeating:0,count:w*h*4) }
 func color(_ i: Int) -> [UInt8] { Array(p[i*4..<i*4+4]) }
 mutating func set(_ i: Int,_ c:[UInt8]) { p.replaceSubrange(i*4..<i*4+4,with:c) }
 func write(_ path: String) throws {
  let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:.alphaNonpremultiplied,bytesPerRow:w*4,bitsPerPixel:32)!
  p.withUnsafeBytes { rep.bitmapData!.update(from:$0.bindMemory(to:UInt8.self).baseAddress!,count:p.count) }
  try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
 }
 func components(_ predicate:(Int)->Bool) -> [[Int]] {
  var seen=Set<Int>(); var result=[[Int]]()
  for i in 0..<w*h where !seen.contains(i) && predicate(i) {
   var q=[i]; seen.insert(i); var k=0
   while k<q.count { let j=q[k]; k+=1
    for (dx,dy) in [(-1,0),(1,0),(0,-1),(0,1)] { let x=j%w+dx,y=j/w+dy
     if x>=0 && x<w && y>=0 && y<h { let n=y*w+x; if !seen.contains(n) && predicate(n) { seen.insert(n); q.append(n) } }
    }
   }
   result.append(q)
  }
  return result.sorted { $0.count>$1.count }
 }
 func cyan(_ i:Int)->Bool { let c=color(i); return c[3]>32 && Int(c[1])>Int(c[0])+65 && Int(c[2])>Int(c[0])+65 && c[1]>150 }
 func orange(_ i:Int)->Bool { let c=color(i); return c[3]>32 && c[0]>190 && c[1]>55 && c[1]<190 && c[2]<80 }
}
struct Failure: Error { let message:String; init(_ s:String){message=s} }
func box(_ a:[Int],_ w:Int)->String { "x=\(a.map{$0%w}.min()!)...\(a.map{$0%w}.max()!), y=\(a.map{$0/w}.min()!)...\(a.map{$0/w}.max()!), pixels=\(a.count)" }
struct Bounds {
 let x0:Int,y0:Int,x1:Int,y1:Int
 init(_ a:[Int],_ w:Int) { x0=a.map{$0%w}.min()!; x1=a.map{$0%w}.max()!; y0=a.map{$0/w}.min()!; y1=a.map{$0/w}.max()! }
 var cx:Int {(x0+x1)/2}; var cy:Int {(y0+y1)/2}
}
struct Regions {
 var eyes:[[Int]]; var screen:[Int]; var antenna:[Int]; var ball:[Int]; var keys:[[Int]]; var head:[Int]
}
func detect(_ r:Raster)->Regions {
 let cyans=r.components {r.cyan($0)}
 let oranges=r.components {r.orange($0)}.filter{$0.count>200}
 let ball=oranges.min{Bounds($0,r.w).y0<Bounds($1,r.w).y0}!
 let bb=Bounds(ball,r.w)
 let patch=oranges.filter{Bounds($0,r.w).y0>bb.y1}.min{Bounds($0,r.w).y0<Bounds($1,r.w).y0}!
 let pb=Bounds(patch,r.w)
 // Find paired substantial cyan components below the head patch; no fixed eye coordinates.
 let candidates=cyans.filter { let b=Bounds($0,r.w); return $0.count>400 && b.y0>pb.y1 && b.x0>bb.cx && b.x1<pb.x1+(pb.x1-pb.x0) }
 let first=candidates.min{Bounds($0,r.w).y0<Bounds($1,r.w).y0}!
 let fb=Bounds(first,r.w)
 let eyes=candidates.filter{abs(Bounds($0,r.w).cy-fb.cy)<4}.sorted{Bounds($0,r.w).cx<Bounds($1,r.w).cx}
 precondition(eyes.count==2,"Expected exactly two eyes")
 let eb=Bounds(eyes.flatMap{$0},r.w)
 let dark=r.components { let c=r.color($0); return c[3]>32 && c[0]<65 && c[1]<65 && c[2]<90 }
 let screen=dark.first { let b=Bounds($0,r.w); return b.x0<eb.x0 && b.x1>eb.x1 && b.y0<eb.y0 && b.y1>eb.y1 && b.y0>pb.y1 }!
 let sb=Bounds(screen,r.w)
 // Include every nonzero-alpha fringe pixel in the separated upper silhouette.
 let antenna=(0..<r.w*r.h).filter{r.p[$0*4+3]>0 && $0/r.w<pb.y0-8 && abs($0%r.w-bb.cx)<(bb.x1-bb.x0)}
 // Neck is the narrowest opaque silhouette below the face and above the chest.
 let chest=cyans.filter{let b=Bounds($0,r.w);return $0.count>250 && b.y0>sb.y1 && b.x0>eb.x0 && b.x1<eb.x1}.min{Bounds($0,r.w).y0<Bounds($1,r.w).y0}!
 let cb=Bounds(chest,r.w)
 let neck=(sb.y1+1..<cb.y0).min { a,b in
  func span(_ y:Int)->Int { let xs=(0..<r.w).filter{r.p[(y*r.w+$0)*4+3]>32}; return (xs.last ?? 0)-(xs.first ?? 0) }
  return span(a)<span(b)
 }!
 let head=r.components{r.p[$0*4+3]>32 && $0/r.w<neck}.first!
 let keys=cyans.filter{let b=Bounds($0,r.w); return $0.count>=12 && b.y0>cb.y1+(cb.y1-cb.y0) && b.x0>eb.x0-30 && b.x1<=eb.x1 && b.x1-b.x0<=25 && b.y1-b.y0<=8}
 return Regions(eyes:eyes,screen:screen,antenna:antenna,ball:ball,keys:keys,head:head)
}
func modeColor(_ r:Raster,_ indices:[Int])->[UInt8] {
 var counts=[[UInt8]:Int]()
 for i in indices { counts[r.color(i),default:0]+=1 }
 return counts.keys.sorted{let a=counts[$0]!,b=counts[$1]!; return a==b ? $0.lexicographicallyPrecedes($1) : a>b}.first!
}
func blink(_ source:Raster,_ regions:Regions,_ output:inout Raster) {
 let screenColor=modeColor(source,regions.screen)
 let cyan=modeColor(source,regions.eyes.flatMap{$0})
 for eye in regions.eyes {
  let b=Bounds(eye,source.w)
  // Repaint the full component-derived eye box, including dark cyan fringe.
  // A 2-px margin left a faint box of rim pixels; 4 px clears it.
  for y in b.y0-4...b.y1+4 { for x in b.x0-4...b.x1+4 {
   let i=y*source.w+x
   output.set(i,screenColor)
  }}
  // One art pixel is about 6 px here; a 2-px line read as a scratch, not a closed eye.
  for y in b.cy-2...b.cy+3 { for x in b.x0...b.x1 { output.set(y*source.w+x,cyan) } }
 }
}
// Antenna "spring": the ball and its dark collar dip `dy` px (one art pixel,
// 6 px) into the top of the stem and back. Sideways sway on this short stem
// needed sub-art-pixel shifts and always left a jag; a vertical move doesn't.
func sway(_ source:Raster,_ regions:Regions,_ dy:Int,_ output:inout Raster) {
 guard dy > 0 else {return}
 let bb=Bounds(regions.ball,source.w), ab=Bounds(regions.antenna,source.w)
 // The collar is included, but the moved rows must stay above the stem's base on the head.
 let x0=max(0,ab.x0-8), x1=min(source.w-1,ab.x1+8), top=ab.y0, bottom=min(bb.y1+8, ab.y1-1-dy)
 // Clear the old ball rows and the stem rows it now covers, so no ghost outline stays.
 for y in top...(bottom+dy) { for x in x0...x1 { output.set(y*source.w+x,[0,0,0,0]) } }
 for y in stride(from:bottom, through:top, by:-1) { for x in x0...x1 {
  let i=y*source.w+x
  if source.p[i*4+3]>0 { output.set(i+dy*source.w,source.color(i)) }
 }}
}
func pressKey(_ r:Raster,_ regions:Regions)->[Int] {
 let eb=Bounds(regions.eyes[0],r.w), sb=Bounds(regions.screen,r.w)
 let ground=(0..<r.w*r.h).filter{r.p[$0*4+3]>32}.map{$0/r.w}.max()!
 let white=(0..<r.w*r.h).filter {i in
  let x=i%r.w,y=i/r.w,c=r.color(i)
  return x>=eb.x0-30 && x<=eb.x1+20 && y>sb.y1+(sb.y1-sb.y0) && y<ground-30 && c[3]>32 && c[0]>185 && c[1]>180 && c[2]>170
 }
 let lowest=white.map{$0/r.w}.max()!
 let tip=white.filter{$0/r.w>=lowest-2}; let x=tip.reduce(0){$0+$1%r.w}/tip.count
 // Local connectivity separates the key directly beneath the fingertip even
 // when its cyan outline touches another key in the full-image component.
 let nearby=r.components {i in let px=i%r.w,py=i/r.w
  return r.cyan(i) && abs(px-x)<=10 && py>=lowest && py<=lowest+9
 }
 return nearby.first!

}
struct Step {let source:Int; let dx:Int; let blink:Bool; let glow:Bool; let ms:Int}
let steps:[Step] = [
 // `dx` is now the antenna dip in px (0 or 6).
 Step(source:1,dx:0,blink:false,glow:false,ms:160),
 Step(source:2,dx:0,blink:false,glow:true,ms:140),
 Step(source:2,dx:6,blink:false,glow:false,ms:150),
 Step(source:3,dx:0,blink:false,glow:true,ms:140),
 Step(source:3,dx:0,blink:false,glow:false,ms:160),
 Step(source:4,dx:0,blink:false,glow:false,ms:150),
 Step(source:4,dx:6,blink:false,glow:false,ms:150),
 Step(source:1,dx:0,blink:true,glow:false,ms:100),
 Step(source:1,dx:6,blink:true,glow:false,ms:100),
 Step(source:2,dx:0,blink:false,glow:true,ms:140),
 Step(source:2,dx:0,blink:false,glow:false,ms:160),
 Step(source:3,dx:0,blink:false,glow:true,ms:140),
 Step(source:3,dx:0,blink:false,glow:false,ms:170),
 Step(source:1,dx:6,blink:false,glow:false,ms:190)
]
func changed(_ a:Raster,_ b:Raster)->Int {(0..<a.w*a.h).filter{a.color($0) != b.color($0)}.count}
func count(_ r:Raster,_ threshold:UInt8)->Int {(0..<r.w*r.h).filter{r.p[$0*4+3]>threshold}.count}
func bottom(_ r:Raster)->Int {r.components{r.p[$0*4+3]>32}.first!.map{$0/r.w}.max()!}
do {
 let args=CommandLine.arguments; guard args.count==3 else {throw Failure("Usage: generator companion-dir diagnostic-output-dir")}
 let fm=FileManager.default
 let sourcePaths=(1...4).map{"\(args[1])/frame\($0).png"}
 let originalData=try sourcePaths.map{try Data(contentsOf:URL(fileURLWithPath:$0))}
 let sources=try sourcePaths.map{try Raster($0)}
 precondition(sources.allSatisfy{$0.w==627 && $0.h==627})
 let regions=sources.map{detect($0)}
 let outputDir="\(args[1])/typing",diagnostics=args[2]
 try fm.createDirectory(atPath:outputDir,withIntermediateDirectories:true)
 try fm.createDirectory(atPath:diagnostics,withIntermediateDirectories:true)
 var report=[String]()
 func log(_ s:String){FileHandle.standardOutput.write(Data((s+"\n").utf8));report.append(s)}
 log("Coordinates: top-left origin. Opaque = alpha >32. Pixels decoded/encoded as unassociated RGBA; no resampling of animation frames.")
 for (n,g) in regions.enumerated() {
  log("SOURCE \(n+1): eyes \(g.eyes.map{box($0,627)}.joined(separator:"; ")); face screen \(box(g.screen,627))")
  log("  antenna \(box(g.antenna,627)); orange ball \(box(g.ball,627)); head candidate \(box(g.head,627)) [bob skipped]")
  log("  key candidates: \(g.keys.map{box($0,627)}.joined(separator:"; "))")
  if n==1 || n==2 {log("  selected press key: \(box(pressKey(sources[n],g),627))")}
 }
 var outputs=[Raster](); var entries=[[String:Any]](); var maxDelta=0.0
 for (n,s) in steps.enumerated() {
  let src=sources[s.source-1],g=regions[s.source-1];var out=src
  sway(src,g,s.dx,&out)
  if s.blink {blink(src,g,&out)}
  if s.glow {
   let bright=(0..<src.w*src.h).filter{src.cyan($0) && src.p[$0*4+3]==255}.map{src.color($0)}.sorted{
    let a=Int($0[0])+Int($0[1])+Int($0[2]),b=Int($1[0])+Int($1[1])+Int($1[2]);return a==b ? $0.lexicographicallyPrecedes($1) : a>b
   }.first!
   for i in pressKey(src,g) {var c=bright;c[3]=src.p[i*4+3];out.set(i,c)}
  }
  let file=String(format:"t%02d.png",n+1),path="\(outputDir)/\(file)"
  if n==0 {try originalData[0].write(to:URL(fileURLWithPath:path))} else {try out.write(path)}
  let decoded=try Raster(path)
  precondition(decoded.p==out.p,"PNG roundtrip altered pixels")
  let palette=Set((0..<src.w*src.h).map{src.color($0)})
  precondition((0..<out.w*out.h).allSatisfy{palette.contains(out.color($0))},"New RGBA color introduced")
  let subject=Set(out.components{out.p[$0*4+3]>32}.first!)
  precondition(g.ball.allSatisfy{subject.contains($0+s.dx*627)},"Antenna detached")
  var allowed=Set(g.antenna)
  do {let ab=Bounds(g.antenna,627);for y in ab.y0...(Bounds(g.ball,627).y1+14) {for x in (ab.x0-8)...(ab.x1+8) {allowed.insert(y*627+x)}}}
  if s.blink {for eye in g.eyes {let b=Bounds(eye,627);for y in b.y0-4...b.y1+4 {for x in b.x0-4...b.x1+4 {allowed.insert(y*627+x)}}}}
  if s.glow {allowed.formUnion(pressKey(src,g))}
  precondition((0..<627*627).allSatisfy{allowed.contains($0) || src.color($0)==out.color($0)},"Unintended body or laptop edit")
  precondition(decoded.w==627 && decoded.h==627)
  precondition(bottom(decoded)==bottom(src),"Ground moved")
  // Entire bottom 20 rows of the opaque subject are byte-identical to the source.
  let ground=bottom(src)
  precondition(Array(decoded.p[(ground-20)*627*4..<decoded.p.count])==Array(src.p[(ground-20)*627*4..<src.p.count]))
  for threshold:UInt8 in [0,32] {
   let delta=100*Double(abs(count(out,threshold)-count(src,threshold)))/Double(count(src,threshold))
   maxDelta=max(maxDelta,delta); precondition(delta<1,"Pixel count changed >=1%")
  }
  if let prev=outputs.last {precondition(changed(prev,out)>0,"Duplicate consecutive frames")}
  outputs.append(out);entries.append(["file":file,"ms":s.ms])
  log("\(file): source=\(s.source), antenna dip=\(s.dx)px, blink=\(s.blink), glow=\(s.glow), \(s.ms)ms; PASS 627x627 bottom=\(ground) alpha>0=\(count(out,0)) alpha>32=\(count(out,32))")
 }
 let transitions=outputs.indices.map{changed(outputs[$0],outputs[($0+1)%outputs.count])}
 let seam=transitions.last!
 log("SEAM changed pixels: \(seam), opaque: \(count(outputs[0],32))")
 precondition(seam>0 && seam<4000,"Loop seam too large")
 precondition(Double(seam)/Double(627*627)<0.005)
 let antBounds=Bounds(regions[0].antenna,627)
 for i in 0..<627*627 where outputs.last!.color(i) != outputs[0].color(i) {precondition(i%627>=antBounds.x0-6 && i%627<=antBounds.x1+6 && i/627>=antBounds.y0 && i/627<=antBounds.y1)}
 log("PASS: \(steps.count) frames, \(steps.reduce(0){$0+$1.ms})ms; all 627x627; source body/laptop bottom rows unchanged (including original 536/537 variation).")
 log(String(format:"PASS: maximum alpha>0 / alpha>32 count difference %.5f%% (<1%%).",maxDelta))
 log("PASS: all consecutive frames distinct; changed pixels per transition (last is seam): \(transitions)")
 log("PASS: loop seam \(seam) changed pixels, only an antenna return; <0.5% of canvas, confined to antenna, and <4000 pixels.")
 // Exact 1:4 nearest-neighbour point sampling. 627/4 rounds up to 157 so canvas is retained.
 let panel=157;var sheet=Raster(panel*outputs.count,panel)
 let commonBottom=sources.map{bottom($0)}.max()!
 for y in 0..<panel {for x in 0..<sheet.w {
  let frame=x/panel,sx=min(626,(x%panel)*4),sy=min(626,y*4)
  var c=outputs[frame].color(sy*627+sx)
  if y==commonBottom/4 {c=[255,0,0,255]}
  sheet.set(y*sheet.w+x,c)
 }}
 let sheetPath=URL(fileURLWithPath:diagnostics).deletingLastPathComponent().appendingPathComponent("sheet.png").path
 try sheet.write(sheetPath)
 let json=try JSONSerialization.data(withJSONObject:["frames":entries],options:[.prettyPrinted,.sortedKeys])
 try json.write(to:URL(fileURLWithPath:"\(outputDir)/sequence.json"))
 for (i,path) in sourcePaths.enumerated() {let data = try Data(contentsOf:URL(fileURLWithPath:path)); precondition(data==originalData[i],"Source changed")}
 log("PASS: exact PNG round trips; original RGBA palette only; antenna connected; pixels outside declared edits unchanged.")
 log("PASS: source PNGs byte-unchanged. Sheet: \(sheetPath), 2512x157, nearest-neighbour, red baseline y=\(commonBottom).")
 log("SKIPPED: head bob; candidate head shares its lower outline with neck/shoulders, so no uncertain body reconstruction is performed.")
 try (report.joined(separator:"\n")+"\n").write(toFile:"\(diagnostics)/verification.txt",atomically:true,encoding:.utf8)
} catch {print("ERROR \(error)");exit(1)}
