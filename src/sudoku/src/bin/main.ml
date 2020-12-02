(* file: main.ml
  author: Bob muller

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

let play2String {row; col; number} =
  Lib.fmt "{row=%d; col=%d; number=%d}" row col number

let printPlay play = Lib.pfmt "%s\n" (play2String play)

type memory = play Stack.t

let printMemory memory =
  Lib.pfmt "memory=\n";
  Stack.iter printPlay memory

type model = { state  : state
             ; memory : memory
             ; board  : board
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

let initialModel = { state = Paused
                   ; memory = Stack.create ()
                   ; board = readBoard ()
                   }

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
let view { board } =
  let n = Array.length board in
  let rec loop row col image =
    let digitImage = boxOf board.(row).(col) in
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
let sectionOK number board i j =
  true (* THIS IS WRONG, YOUR CODE HERE *)

let rowOK number board i j =
  true (* THIS IS WRONG, YOUR CODE HERE *)

let colOK number board i j =
  true (* THIS IS WRONG, YOUR CODE HERE *)

let numberOK number board row col =
  rowOK number board row col &&
  colOK number board row col &&
  sectionOK number board row col

(* update : model -> model *)
let update ({ state; memory; board } as model) =
  match state with
  | Paused | Solved -> model
  | Running ->
    model (* THIS IS WRONG, YOUR CODE HERE *)

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
      ~rate: clockRate
      ~onTick: update
      ~onMouse: handleMouse
      ~stopWhen: finished
      ~viewLast: view

let s = go()
