open Types

(* function composition *)
let (<<) f g x = f(g(x));;

let isSome = function 
  | Some _ -> true 
  | None -> false;;

let deoptionalize lst = 
  List.filter isSome lst
  |> List.map (function 
      | Some x -> x 
      | None -> assert false
    );;
(* define an infix operator to create a range between numbers. WTF this is crazy *)
let (<->) i j = 
  let rec aux n acc =
    if n < i then acc else aux (n-1) (n :: acc)
  in aux j [] ;;

let rec repeat s n = 
  if n = 0 then "" else s ^ (repeat s (n - 1));;

let padWithZeros (str:string) (n:int) = 
  let strlen = String.length str in
  if strlen >=n 
  then str
  else (repeat "0" (n - strlen)) ^ str
;;

let find_opt f lst = try Some (List.find f lst) with Not_found -> None;;

(* let height = 256;; (* original was 224 x 256 *)
   let width = 224;; *)

(* Frogger had a 14:16 ratio, so lets stick with that and scale at the render step *)
let height = 480;;
let width = 420;;
let rows = 16;;
let cols = 14;;
let tileSize = height / rows ;;
let halfTileSize = tileSize / 2;;

let getRowForY y = (height - y) / tileSize;;
let getYForRow row = height - ((row) * tileSize);;

let intersects (rect1:rectT) (rect2:rectT) =
  let bottom1 = rect1.y +. (float_of_int rect1.height) in
  let bottom2 = rect2.y +. (float_of_int rect2.height) in
  let top1 = rect1.y in
  let top2 = rect2.y in
  let left1 = rect1.x in 
  let left2 = rect2.x in
  let right1 = rect1.x +. (float_of_int rect1.width) in 
  let right2 = rect2.x +. (float_of_int rect2.width ) in
  not ((bottom1 < top2 )|| 
       (top1 > bottom2) ||
       (right1 < left2) || 
       (left1 > right2));;

let isRectOutOfBounds rect = 
  let x = int_of_float rect.x in
  let y = int_of_float rect.y in
  x + rect.width < 0 ||
  x > width || 
  y + rect.height < 0 ||
  y > (height - tileSize)
;;

let isRectInBounds =  not << isRectOutOfBounds;;


external spritesUrl: string = "../assets/frogger_sprites2.png" [@@bs.module];;
external frogGoalUrl: string = "../assets/goal_frog_0.png" [@@bs.module];;
external lifeUrl: string = "../assets/life.png" [@@bs.module];;

let spriteSheet = Webapi.Dom.HtmlImageElement.make ();;
(Webapi.Dom.HtmlImageElement.src spriteSheet spritesUrl);;

let goalSprite = Webapi.Dom.HtmlImageElement.make ();;
(Webapi.Dom.HtmlImageElement.src goalSprite frogGoalUrl);;

let lifeSprite = Webapi.Dom.HtmlImageElement.make ();;
(Webapi.Dom.HtmlImageElement.src lifeSprite lifeUrl);;

let makeSpriteImage ?(number=1) ?(height=30) xStart yStart frames frameSpeed width = { 
  xStart; yStart; frames; frameSpeed; width; height; number;
};;

let yellowCarImage = makeSpriteImage 80 262 0 0. 33;;
let greenCarImage = makeSpriteImage 70 296 0 0. 33;;
let pinkCarImage = makeSpriteImage 10 262 0 0. 31;;
let raceCarImage = makeSpriteImage 40 260 0 0. 33;;
let whiteTruckImage = makeSpriteImage 110 296 0 0. 43;;
let threeTurtleImage = makeSpriteImage ~number:3 15 402 3 2. 35;;
let divingThreeTurtles = makeSpriteImage ~number:3 15 402 6 2. 36;;
let twoTurtleImage = makeSpriteImage ~number:2 15 402 3 2. 35;;
let divingTwoTurtles = makeSpriteImage ~number:2 15 402 6 2. 36;;
let smallLogImage = makeSpriteImage 10 225 0 0. 80;;
let mediumLogImage = makeSpriteImage 10 193 0 0. 115;;
let bigLogImage = makeSpriteImage 10 162 0 0. 175;;
let frogUp = makeSpriteImage ~height:23 8 370 2 20. 28;;
let frogDown = makeSpriteImage ~height:23 76 370 2 20. 28;;
let frogLeft = makeSpriteImage ~height:28 76 336 2 20. 33;;
let frogRight = makeSpriteImage ~height:28 8 336 2 20. 33;;
