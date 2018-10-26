module CompleteCarte = struct
    module Node = struct
        type t = int
        let compare x y = x - y
    end

    type node = Node.t
    type pair = string * (float * float)

    module IntMap = Map.Make(Node)
    type graph = pair IntMap.t

    let distance_squared u v g =
        let data_u = IntMap.find u g in
        let data_v = IntMap.find v g in
        match data_u, data_v with
        | (_, (xu, yu)), (_, (xv, yv)) -> (((xu -. xv) *. (xu -. xv) +. (yu -. yv) *. (yu -. yv)))

    let distance u v g =
        distance_squared u v g ** (1. /. 2.)

    let rec distance_path path g = match path with
    | [] -> 0.
    | [_] -> 0. (* A path with only one point has no length *)
    | a::(b::t) ->
        (distance a b g) +.
        (distance_path (b::t) g) (* TODO: Possible optimization here *)

    let empty = IntMap.empty

    let add_node index name x y g =
        IntMap.add index (name, (x, y)) g
end