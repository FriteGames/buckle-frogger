external toUnsafe : 'a -> < .. > Js.t = "%identity"

open Utils
open Types

let savedHighScore = match (Dom.Storage.getItem "highscore" Dom.Storage.localStorage) with
  | Some n -> int_of_string n;
  | None -> 0
;;

(* Represents the values of relevant key bindings. *)
let pressedKeys = {
  direction = None;
  bbox = false;
  grid = false;
};;

(* Keydown event handler translates a key press *)
let keydown (evt:Dom.event) =
  match (toUnsafe evt)##keyCode with
  | 38 | 32 | 87 -> pressedKeys.direction <- Some Up
  | 39 | 68 -> pressedKeys.direction <- Some Right
  | 37 | 65 -> pressedKeys.direction <- Some Left
  | 40 | 83 -> pressedKeys.direction <- Some Down
  | 66 -> pressedKeys.bbox <- (not pressedKeys.bbox)
  | 71 -> pressedKeys.grid <- (not pressedKeys.grid)
  | _ -> Js.log ("did not find nothing" ^ ((toUnsafe evt)##keyCode))
;;

let xDown : int option ref = ref None;;
let yDown : int option ref = ref None;;

let handleTouchStart evt = 
  xDown := Some [%raw "arguments[0].touches[0].clientX"];
  yDown := Some [%raw "arguments[0].touches[0].clientY"];
  ();
;;

let handleTouchMove evt = 
  match (!xDown, !yDown) with
  | (Some xdwn, Some ydwn) ->
    let xUp = [%raw "arguments[0].touches[0].clientX"] in
    let yUp = [%raw "arguments[0].touches[0].clientY"] in
    let xDiff = xdwn - xUp in
    let yDiff = ydwn - yUp in
    if abs xDiff > abs yDiff then 
      pressedKeys.direction <- if xDiff > 0 then Some Left else Some Right
    else
      (pressedKeys.direction <- if yDiff > 0 then Some Up else Some Down);

  | (_,_) -> ();
;;

(Webapi.Dom.Window.addEventListener "touchstart" handleTouchStart Webapi.Dom.window );;
(Webapi.Dom.Window.addEventListener "touchmove" handleTouchMove Webapi.Dom.window );;
(Webapi.Dom.Window.addEventListener "keydown" keydown Webapi.Dom.window );;

let startWorld : worldT = { 
  frog = { 
    rect = { 
      x = float_of_int (tileSize * (cols / 2 -1) ); 
      y = float_of_int (getYForRow 2 + 8);  
      width = 10;
      height = 10;
    };
    direction = Up;
    leftInJump = 0.;
  };
  objects = [];
  keys = pressedKeys;
  state = Start;
  lives = 5;
  score = 0;
  maxRow = 1;
  highscore = savedHighScore;
  timer = 30 * 1000;
  endzone = [ (0, false); (1,false); (2,false); (3,false); (4,false);]
};;

let endzoneRects = 
  (List.map (fun i ->
       let x = (float_of_int ((3*i*tileSize) +halfTileSize-(1*i))) in
       let rect = { 
         x; 
         y = (float_of_int (tileSize*2)); 
         width = tileSize; 
         height= tileSize;
       } in
       (i, rect)
     ) (0<->4))
;;

let secondsPerWidthToPixels vel dt = 
  let speed = (float_of_int width) /. vel in
  speed *. (float_of_int dt) /. 1000.;;

let updateObj obj dt = { obj with 
                         rect = { obj.rect with 
                                  x = obj.rect.x +. secondsPerWidthToPixels obj.velocity dt
                                };
                         frameIndex = 
                           let nextFrameIndex = (obj.frameIndex +. ((float_of_int dt) *. obj.img.frameSpeed )) in
                           if (int_of_float (nextFrameIndex /. 1000.)) < obj.img.frames then nextFrameIndex else 0.;
                       };;

let updateFrog frog (collisions:laneObjectT list) dt = 
  let floatedX = try 
      let floatieThing = List.find (fun (obj:laneObjectT) -> match obj.objType with BasicFloater -> true | _ -> false) collisions in
      secondsPerWidthToPixels floatieThing.velocity dt 
    with Not_found -> 0. in
  if frog.leftInJump > 0. then
    let distanceToTravel = min ((float_of_int tileSize) *. ((float_of_int dt) /. 100. )) frog.leftInJump in
    { frog with 
      rect = {
        frog.rect with
        x = frog.rect.x +. ( distanceToTravel *. match frog.direction with Left -> -1. | Right -> 1. | _ -> 0. ) +. floatedX;
        y = frog.rect.y +. ( distanceToTravel *. match frog.direction with Down -> 1. | Up -> -1. | _ -> 0. );
      };
      leftInJump = frog.leftInJump -. distanceToTravel;
    }
  else match pressedKeys.direction with 
    | None -> { frog with rect= { frog.rect with x = frog.rect.x +. floatedX } }
    | Some direction -> 
      let nextRect = {frog.rect with
                      x = frog.rect.x +. ( (float_of_int tileSize) *. match direction with Left -> -1. | Right -> 1. | _ -> 0. );
                      y = frog.rect.y +. ( (float_of_int tileSize) *. match direction with Down -> 1. | Up -> -1. | _ -> 0. );
                     } in
      let isValid = not (rect_out_of_bounds nextRect) in
      if isValid 
      then {frog with direction; leftInJump = float_of_int tileSize; }
      else frog
;;

let isCar (obj:laneObjectT) = match obj.objType with Car -> true | _ -> false;; 

let makeLaneObject ((row, { img; velocity; objType; }): (int * laneConfigT)) = 
  let direction = if velocity > 0. then Right else Left in 
  {
    rect = {
      x = (match direction with 
          | Right -> float_of_int (-img.width) 
          | Left -> float_of_int width
          | Up | Down -> assert false);
      y = float_of_int (getYForRow row);
      width = img.width * img.number;
      height = img.height;
    };
    direction;
    img;
    velocity;
    objType;
    frameIndex = 0.;
  };;

let getJitter () = Random.int 1000 ;;
let getJitterFromNow () = (int_of_float (Js.Date.now ())) + (getJitter ());;

(* velocities is the number of seconds it takes to cross the screen. the smaller the faster *)
let laneConfig = [
  (3, { velocity = -10.; objectsAtOnceIsh = 4.; nextSpawnTime = (getJitterFromNow ()); objType = Car; img = yellowCarImage;} );
  (4, { velocity = 6.; objectsAtOnceIsh = 3.; nextSpawnTime = (getJitterFromNow ()); objType = Car ;img = greenCarImage; } );
  (5, { velocity = -6.; objectsAtOnceIsh = 4.; nextSpawnTime = (getJitterFromNow ()); objType = Car ; img=pinkCarImage; } );
  (6, { velocity = 6.; objectsAtOnceIsh = 2.; nextSpawnTime = (getJitterFromNow ()); objType = Car; img=raceCarImage;} );
  (7, { velocity = -6.; objectsAtOnceIsh = 3.; nextSpawnTime = (getJitterFromNow ()); objType = Car; img=whiteTruckImage;});
  (9, { velocity = -10.; objectsAtOnceIsh = 2.; nextSpawnTime = (getJitterFromNow ()); objType = BasicFloater; img=threeTurtleImage;} );
  (10, { velocity = 6.; objectsAtOnceIsh = 3.; nextSpawnTime = (getJitterFromNow ()); objType = BasicFloater; img=smallLogImage;} );
  (11, { velocity = 4.; objectsAtOnceIsh = 1.7; nextSpawnTime = (getJitterFromNow ()); objType = BasicFloater; img=bigLogImage; } );
  (12, {velocity = -6.; objectsAtOnceIsh = 2.; nextSpawnTime = (getJitterFromNow ()); objType = BasicFloater; img=twoTurleImage;} );
  (13, {velocity = 5.; objectsAtOnceIsh = 3.; nextSpawnTime = (getJitterFromNow ()); objType = BasicFloater; img=mediumLogImage; } );
];; 

let stepWorld world now dt = 
  let collisions = List.filter (fun obj -> intersects obj.rect world.frog.rect ) world.objects in
  let endzoneCollisions = List.filter (fun (_,rect) -> intersects rect world.frog.rect ) endzoneRects in 
  let hasCarCollision = List.exists isCar collisions in
  let isInWater = List.length collisions = 0 && (getRowForY (int_of_float world.frog.rect.y)) > 7 && world.frog.leftInJump = 0. in
  let isOutOfBounds = rect_out_of_bounds world.frog.rect in
  let timerIsUp = world.timer <= 0 in
  let frog = updateFrog world.frog collisions dt in
  let movedLaneObjects = (List.map (fun o -> updateObj o dt ) world.objects) 
                         |> List.filter (fun obj -> not (rect_out_of_bounds obj.rect)) in
  let newLaneObjects = (List.map
                          (fun (rowNum, (cfg:laneConfigT)) -> if now > cfg.nextSpawnTime then (
                               cfg.nextSpawnTime <- (getJitterFromNow ()) + (int_of_float ((abs_float cfg.velocity) *. 1000. /. cfg.objectsAtOnceIsh ));
                               Some (makeLaneObject (rowNum, cfg));
                             ) 
                             else None) laneConfig) |> deoptionalize in
  let objects = (movedLaneObjects @ newLaneObjects ) in 
  let newFrogRow = getRowForY (int_of_float frog.rect.y) in
  let score = if newFrogRow > world.maxRow then world.score + 10 else world.score in
  let highscore = if score > world.highscore then (
      (Dom.Storage.setItem "highscore" (string_of_int score) Dom.Storage.localStorage);
      score;
    ) else world.highscore in
  if (List.length endzoneCollisions) > 0 then (
    let (ithCollision, _ ) = (List.hd endzoneCollisions)in
    let endzone = (List.map (fun (i, curr) -> (i, curr || ithCollision = i)) world.endzone) in
    if not (List.exists (fun (_, boo) -> not boo ) endzone) then { world with state=Won}
    else { world with 
           frog = startWorld.frog; 
           timer = startWorld.timer; 
           maxRow = startWorld.maxRow;
           score = score + 200;
           endzone; 
         };
  ) 
  else if hasCarCollision || isInWater || timerIsUp || isOutOfBounds then ( 
    if world.lives = 1
    then { world with state = Lose } 
    else { world with 
           frog=startWorld.frog; 
           timer=startWorld.timer; 
           lives=world.lives-1 
         }
  ) else (
    { world with 
      frog; 
      objects; 
      score; 
      maxRow = max newFrogRow world.maxRow;
      timer = world.timer - dt; 
      highscore;
    }
  ) 
;;