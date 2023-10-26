(* file: main.ml
 author: Thomas Bardhi

 CSCI 1103 Computer Science 1 Honors

  A sudoku solver.

 To run:

 > cd src
 > dune exec bin/main.exe inputfile
*)
let boardSize = ref 0

let displayWidth  = 800.0
let displayHeight = 800.0
let side = displayWidth /. 9.0
let empty = Image.empty displayWidth displayHeight
let emptySquare = Image.rectangle side side Color.gray
let digitSize = 50.0
let offset = (side -. digitSize) /. 1.5
let clockRate = 0.005

type entry = { n : int; fixed : bool }
type board = entry array array

let printBoard board =
 let n = Array.length board
 in
 for row = 0 to n - 1 do
   for col = 0 to n - 1 do
     Lib.pfmt "%d " board.(row).(col).n
   done ;
   print_string "\n"
 done ;
 print_string "\n"

type state = Paused | Running | Solved

let toggle state =
 match state with
 | Paused -> Running
 | Running | Solved -> Paused

type play = { row : int
           ; col : int
           ; number : int
           }
type loc = {row: int;
          col: int}

let play2String {row; col; number} =
 Lib.fmt "{row=%d; col=%d; number=%d}" row col number

let printPlay play = Lib.pfmt "%s\n" (play2String play)

type memory =  board Stack.t

let printMemory memory =
 Lib.pfmt "memory=\n";
 Stack.iter printPlay memory

type model = { state  : state
            ; memory : memory
            ; board  : board
            ; location : loc


            }

let charToEntry a =
 { fixed = true
 ; n = if a = '*' then 0 else Char.code(a) - Char.code('0')
 }

(* getFileName : unit -> path *)
let getFilePath () =
 Lib.fmt "%s/%s" (Unix.getcwd ()) Sys.argv.(1)

let readBoard () =
 let filename = getFilePath () in
 let inch = open_in filename in
 let rec loop codeList =
   try
     let line = input_line inch in
     let row = Array.of_list (List.map charToEntry (Lib.explode line))
     in
     loop (row :: codeList)
   with
     End_of_file -> close_in inch ;
     Array.of_list (List.rev codeList)
 in
 boardSize := int_of_string (input_line inch);
 loop []


(* Code related to viewing the model. ******************************
*)
let colorOf entry =
 match entry.fixed with
 | true  -> Color.black
 | false -> Color.dodgerBlue

(* boxOf : entry -> Image.t *)
let boxOf entry =
 let digit = string_of_int entry.n in
 let text = Image.text digit ~size:digitSize (colorOf entry)
 in
 match (1 <= entry.n && entry.n <= 9) with
 | true  -> Image.placeImage text (offset, offset) emptySquare
 | false -> emptySquare

(* view : model -> Image.t *)
let view model =
 let n = Array.length model.board in
 let rec loop row col image =
   let digitImage = boxOf model.board.(row).(col) in
   let x = side *. float col in
   let y = side *. float row in
   let newImage = Image.placeImage digitImage (x, y) image
   in
   match (row = (n - 1), col = (n - 1)) with
   | (true,  true)  -> newImage
   | (true,  false) -> loop row (col + 1) newImage
   | (false, true)  -> loop (row + 1) 0 newImage
   | (false, false) -> loop row (col + 1) newImage
 in
 loop 0 0 empty

(* Code related to updating the model. ******************************
*
* Four functions for checking if a number is acceptable in a spot.
*)
(*sectionOk: int -> entry array array -> int -> int -> bool *)
let sectionOK number board row col =
 let x = row/3 in
 let y = col/3 in
 try
   for i = (3 * x) to (3 * x) + 2 do
     for j = (y * 3) to (3 * y) + 2 do
       if board.(i).(j).n = number then
         raise Exit
     done;
   done;
   true
 with
 |Exit -> false

(*rowOK: int -> entry array array -> int -> int -> bool*)
let rowOK number board row col =
 try
   for i = 0 to 8 do
     if board.(row).(i).n = number then
       raise Exit
   done;
   true
 with
 | Exit -> false

(*colOK: int -> entry array array -> int -> int -> bool *)
let colOK number board row col =
 try
   for i =0 to 8 do
     if board.(i).(col).n = number then
       raise Exit
   done;
   true
 with
 | Exit -> false

(*numberOk: int -> entry array array -> int -> int -> bool *)
let numberOK number board row col =
 rowOK number board row col &&
 colOK number board row col &&
 sectionOK number board row col

(*isSudokuSolved: entry array array -> bool *)
let isSudokuSolved board =
  try
    for i = 0 to 8 do
      for j = 0 to 8 do
        if numberOK board.(i).(j).n board i j= false then
          raise Exit
      done;
    done;
    true
  with
  |Exit -> false

(*entryFail: entry -> entry array array -> int -> int -> bool *)
let entryFail start board row col =
 try
   for i = start.n + 1 to 9 do
     if numberOK i board row col then
       raise Exit
   done;
   true
 with
 | Exit -> false

(*firstWork: entry -> entry array array -> int -> int -> int *)
let firstWork start board row col =
 let count = ref 0 in
 try
   for i = start.n + 1 to 9 do
     if numberOK i board row col then
        (count := i;
         raise Exit)
   done;
   failwith "x"
 with
 | Exit -> !count

(*next: loc -> loc *)
let next location =
 if location.col < 8 then
   {row = location.row; col = location.col + 1}
 else
   {row = location.row + 1;  col = 0}

(*prevEntry: 'a array array -> int -> int -> int -> 'a *)
let prevEntry board row col x =
 if col < x then
   board.(row-1).(8 - (x-col-1))
 else
   board.(row).(col-x)

(*prev: entry array array -> loc -> loc *)
let prev board location =
 let count = ref 1 in
 let subtract =
   try
     for i = 1 to 9 do
       if (prevEntry board location.row location.col i ).fixed then
         count:= !count + 1
       else
         raise Exit
     done;
     !count
   with
   | Exit -> !count in
 if location.col + 1 > subtract then
   {row = location.row; col = location.col - subtract}
 else
   {row = location.row -1; col = 8 - (subtract-location.col-1) }


(*backTrank: model -> model *)
let backTrack model =
 match Stack.is_empty model.memory with
 | true  -> failwith "no solution"
 | false ->
   let newBoard = Stack.pop model.memory
   in
   {state = model.state; memory = model.memory;  board = newBoard; location = prev newBoard model.location}



(* update : model -> model *)
let update ({ state; memory; board; location } as model) =
 let newBoard = Array.copy board in
 let r = location.row in
 let c = location.col in
 match model.state with
 | Paused | Solved -> model
 | Running ->
     match r = 9 with
     | true  -> { model with state = Solved}
     |false ->
         match newBoard.(r).(c).fixed with
         |true->
           {model with location = (next location)}
         |false->
           match entryFail newBoard.(r).(c) newBoard r c with
           |false ->
             Stack.push board memory;
             newBoard.(r).(c) <- {n = firstWork newBoard.(r).(c) newBoard r c; fixed = false};
             {model with board = newBoard; location = next location}
           |true ->
             newBoard.(r).(c) <- {n = 0; fixed = false};
             backTrack {model with board = newBoard}

(*fixedBoard: entry array array -> entry array array*)
let fixedBoard board =
 let newBoard = Array.copy board in
 for i = 0 to 8 do
   for j = 0 to 8 do
     if newBoard.(i).(j).n = 0 then
       newBoard.(i).(j) <- {n = 0; fixed = false}
     else
       newBoard.(i).(j) <- {n = newBoard.(i).(j).n; fixed = true}
   done;
 done;
 newBoard

let initialModel = { state = Paused
                  ; memory = Stack.create ()
                  ; board = fixedBoard (readBoard ())
                  ; location = {row =0; col =0}
                  }


(* finished : model -> bool *)
let finished model = model.state = Solved


(* handleMouse : model -> float -> float -> event -> model *)
let handleMouse model x y event =
 match event = "button_up" with
 | true  -> { model with state = toggle model.state }
 | false -> model

let go () =
 Animate.start initialModel
   ~name: "Sudoku"
   ~width: displayWidth
   ~height: displayHeight
   ~view: view
   ~rate: 0.005
   ~onTick: update
   ~onMouse: handleMouse
   ~stopWhen: finished
   ~viewLast: view


let s = go()
