module Optimizer = struct
    module MLLPath = IMLLPath.MLLPath
    module Carte = ICarte.CompleteCarte

    (*
      Cas card <= 3:
      - Si il n'y a qu'une ville, on ne peut tout simplement pas faire de repositionnement
      - S'il y a deux villes, on obtient le même résultat en repositionnant
      - S'il y a trois villes aussi, puisque c'est "un triangle"
      Sinon, on retire u du chemin et on le rajoute en minimisant la distance totale.
    *)
    let repositionnement_noeud u p c =
        if MLLPath.cardinal p <= 3
        then p
        else
            MLLPath.insert_minimize_length u (MLLPath.remove u p) c

    let inversion_locale a path carte =
        (* From ... -> A -> B -> C -> D -> ... *)
        (* To   ... -> A -> C -> B -> D -> ... *)
        let b = MLLPath.get_next a path in
        let c = MLLPath.get_next b path in
        let d = MLLPath.get_next c path in
        (* let _ = Printf.printf "%d %d %d %d\n" a b c d in  *)
        let swapped = MLLPath.swap b c path in
        let distance_before = Carte.distance a b carte +. Carte.distance b c carte +. Carte.distance c d carte in
        let distance_after = Carte.distance a c carte +. Carte.distance c b carte +. Carte.distance b d carte in
        if distance_after < distance_before
        then
            (* let _ = Printf.printf "S A: %f B: %f\n" distance_after distance_before in  *)
            swapped
        else
            (* let _ = Printf.printf "N A: %f B: %f\n" distance_after distance_before in  *)
            path

    let rec inversion_n_fois solution n c =
        if n = 0
        then solution
        else
            let city, _ = Carte.get_random_any c in
            let swapped = inversion_locale city solution c in
            inversion_n_fois swapped (n - 1) c

        let rebuild_mins_list l new_element carte = 
            let rec aux l new_element = match l with
            | [] -> []
            | (u, current_closest, dist)::t -> 
                (* On calcule la distance entre u et le nouvel élément du chemin,
                   Si elle est inférieure à la distance minimale actuelle, on change l'élément le plus proche. *)
                let dist_new = Carte.distance u new_element carte in 
                if dist_new < dist 
                then (u, new_element, dist_new)::(aux t new_element)
                else (u, current_closest, dist)::(aux t new_element)
            in aux l new_element

        (* Vérifie que la liste des noeuds les plus proches est toujours valable (et la modifie au besoin) *)
        let rec find_closest_index l = 
            let rec aux l = match l with
            | [] -> failwith "empty list"
            | [(u, closest_u, dist)] -> u, closest_u, dist, []
            | (u, closest_u, dist)::t -> 
                let best_u, best_closest, best_dist, l' = aux t in 
                if best_dist < dist 
                then best_u, best_closest, best_dist, (u, closest_u, dist)::l'
                else u, closest_u, dist, (best_u, best_closest, best_dist)::l'
            in aux l
    
        let build_initial_mins_list carte initial = 
            let xi, yi = Carte.get_coordinates initial carte in 
            let rec aux l = match l with
            | [] -> []
            | (idx, (_, (x, y)))::t -> 
                if idx = initial 
                then aux t
                else
                    let dist = Carte.distance_from_coordinates xi yi x y in 
                    (idx, initial, dist)::(aux t)
            in 
            aux (Carte.bindings carte)

        let rec build_solution_nearest carte idx_start =
            let initial_path = MLLPath.make idx_start in 
            let initial_mins_list = build_initial_mins_list carte idx_start in 
            (* Construit un chemin à partir d'un chemin initial p en utilisant la liste des noeuds les plus proches *)
            let rec build_path l p = 
                let new_element, closest_in_path, dist, l' = find_closest_index l in 
                (* let _ = Printf.printf "Adding %d next to %d in " new_element closest_in_path in  *)
                (* let _ = MLLPath.print p in  *)
                (* On insère u dans le chemin, avant ou après closest_u (en fonction d'où ça donne le chemin le plus court) *)
                let p' = MLLPath.insert_before_or_after new_element closest_in_path p carte in 
                match l' with
                | [] -> p' 
                | l' -> 
                    (* On a inséré u dans le chemin, on vérifie qu'il n'est pas devenu le plus proche dans le chemin d'un noeud hors chemin *)
                    let l'' = rebuild_mins_list l' new_element carte in 
                    build_path l'' p'
            in 
            build_path initial_mins_list initial_path

        let rec build_solution_random carte initial =
            let initial_path = MLLPath.make initial in 
            let initial_set = Carte.NodeSet.add initial Carte.NodeSet.empty in 
            let target_card = Carte.card carte in 
            let rec aux card cities_set path = 
                if card = target_card 
                then path
                else
                    let new_element, _ = Carte.get_random carte cities_set in 
                    let cities_set' = Carte.NodeSet.add new_element cities_set in 
                    let path' = MLLPath.insert_minimize_length new_element path carte in 
                    let card' = card + 1 in 
                    aux card' cities_set' path'
            in aux 1 initial_set initial_path

    let rec build_solution_farthest _ = failwith "notimplemented"

    let find_solution builder carte =
        let idx_start, _ = Carte.get_random_any carte in

        let s = Sys.time() in
        let solution = builder carte idx_start in
        let e = Sys.time() in
        let _ = Printf.printf "Temps construction sol initiale: %f\n" (e -. s) in
        (* let _ = Printf.printf "Before: " in *)
        (* let _ = MLLPath.print_with_names solution carte in  *)

        let s = Sys.time() in
        let solution = inversion_n_fois solution 200 carte in
        let e = Sys.time() in
        let _ = Printf.printf "Temps repos: %f\n" (e -. s) in
        let l = MLLPath.to_list solution in 
        let dist = Carte.distance_path l carte in 
        let _ = Printf.printf "Distance: %f\n" dist in 
        (* let _ = Printf.printf "After: " in  *)
        (* let _ = MLLPath.print_with_names solution carte in  *)
        solution

    let find_solution_nearest = find_solution build_solution_nearest
    let find_solution_random = find_solution build_solution_random
end