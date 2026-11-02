
model ChulaMRTRush

// Students leave their buildings when class ends. Part of them walk to
// Sam Yan MRT, the rest to another building. Roads are coloured by how
// crowded they are, to show where the bottlenecks form.

global {


    // 1. File paths

    shape_file buildings_file <- shape_file("../includes/fangyai_buildings.shp");
    shape_file roads_file <- shape_file("../includes/fangyai_roads.shp");

    geometry shape <- envelope(roads_file);

    graph road_network;


    // 2. SETTINGS

    float step <- 1 #s;

    int total_students <- 2000;

    // Share of students who walk to the MRT (the rest go to another building)
    float share_to_mrt <- 0.4;

    // Class ends at this time, students leave their building over release_duration
    float class_end_time <- 1 #mn;
    float release_duration <- 5 #mn;

    // Walking speed in m/s (each student gets a bit of random variation)
    float mean_walking_speed <- 1.3;

    // Assumed width of every footpath, used to turn people per road into people per m²
    float path_width <- 3.0;

    // Sam Yan MRT as {longitude, latitude}. Check it against the exit you want to study.
    point mrt_lonlat <- {100.5294, 13.7325};
    point mrt_target;


    // 3. RESULTS

    int students_created <- 0;
    int arrived_mrt <- 0;
    int arrived_other <- 0;
    list<float> trip_times;
    int max_flow <- 0;


    // 4. Stating

    init {

        // Load buildings
        create building from: buildings_file;

        // Load roads
        // Split roads at intersections and keep only the connected part,
        // otherwise students on isolated pieces can't reach their target
        list<geometry> clean_lines <- clean_network(roads_file.contents, 1.0, true, true);
        create road from: clean_lines;

        // Create pedestrian network
        road_network <- as_edge_graph(road);

        // Snap the station and every building's exit onto the road network
        mrt_target <- closest_on_network(to_GAMA_CRS(mrt_lonlat, "EPSG:4326").location);

        loop b over: building {
            b.exit_point <- closest_on_network(b.location);
        }

        // Spread the students over the buildings by floor area
        float total_area <- sum(building collect each.shape.area);

        ask building {

            create student number: round(total_students * shape.area / total_area) {

                home <- myself;
                location <- myself.exit_point;

                // Not everyone leaves at the same second
                leave_time <- class_end_time + rnd(release_duration);

                speed <- max(0.5, gauss(mean_walking_speed, 0.2));

                going_to_mrt <- flip(share_to_mrt);
                target <- going_to_mrt ? mrt_target : one_of(building - myself).exit_point;
            }
        }

        students_created <- length(student);

        write "Buildings loaded: " + length(building);
        write "Roads loaded: " + length(road);
        write "Students created: " + students_created;
        write "MRT target: " + mrt_target;
    }

    point closest_on_network (point p) {
        road r <- road closest_to p;
        return first(r.shape closest_points_with p);
    }

    // Count who is on which road right now
    reflex measure_crowding {

        ask road {
            crowd <- 0;
        }

        ask student where each.walking {
            road r <- road(current_edge);
            if (r != nil) {
                r.crowd <- r.crowd + 1;
            }
        }

        max_flow <- max(road collect each.total_flow);
    }

    reflex stop_when_done when: cycle > 0 and empty(student) {

        write "All students arrived after " + (time / 60) with_precision 1 + " min";
        write "Arrived at MRT: " + arrived_mrt + ", other buildings: " + arrived_other;
        write "Average trip: " + (mean(trip_times) / 60) with_precision 1 + " min";

        do pause;
    }
}


// 5. BUILDING

species building {

    point exit_point;

    aspect default {

        draw shape
            color: rgb("#D8D2C5")
            border: rgb("#A49E92");
    }
}


// 6. ROADS

species road {

    int crowd <- 0;
    int total_flow <- 0;

    // People per m², assuming the path is path_width wide
    float density -> crowd / (max(1.0, shape.perimeter) * path_width);

    // Colours follow Fruin's walkway level of service (A to F)
    aspect default {

        rgb c <- rgb("#808080");

        if (density > 0.08) { c <- rgb("#2E9E44"); }
        if (density > 0.27) { c <- rgb("#E6C700"); }
        if (density > 0.45) { c <- rgb("#F08C00"); }
        if (density > 0.69) { c <- rgb("#E03131"); }
        if (density > 1.66) { c <- rgb("#7A0000"); }

        // Draw as a band a few metres wide so the colour shows under the students
        draw shape + 4.0 color: c;
    }

    // How many students used each road in total: the busiest road is the thickest
    aspect flow {

        if (total_flow = 0) {
            draw shape + 0.5 color: rgb("#C0C0C0");
        } else {
            draw shape + (1.0 + 9.0 * total_flow / max(1, max_flow)) color: rgb("#6A1B9A");
        }
    }
}


// 7. STUDENTS

species student skills: [moving] {

    building home;
    point target;
    bool going_to_mrt;
    float leave_time;
    bool walking <- false;
    road last_road;

    reflex leave_building when: !walking and time >= leave_time {
        walking <- true;
    }

    reflex walk when: walking {

        do goto target: target on: road_network;

        // Count each student once per road they enter
        road r <- road(current_edge);
        if (r != nil and r != last_road) {
            r.total_flow <- r.total_flow + 1;
            last_road <- r;
        }

        if (location distance_to target < 1.0) {

            trip_times << time - leave_time;

            if (going_to_mrt) {
                arrived_mrt <- arrived_mrt + 1;
            } else {
                arrived_other <- arrived_other + 1;
            }

            do die;
        }
    }

    aspect default {

        if (walking) {
            draw circle(1.5)
                color: going_to_mrt ? rgb("#FF0000") : rgb("#FF9F1C");
        }
    }
}


// 8. EXPERIMENT

experiment chula_rush type: gui {

    parameter "Number of students" var: total_students min: 100 max: 10000 step: 100;
    parameter "Share going to MRT" var: share_to_mrt min: 0.0 max: 1.0 step: 0.05;
    parameter "Release duration (s)" var: release_duration min: 0.0 max: 1800.0 step: 30.0;
    parameter "Walking speed (m/s)" var: mean_walking_speed min: 0.5 max: 3.0 step: 0.1;
    parameter "Path width (m)" var: path_width min: 1.0 max: 10.0 step: 0.5;

    output {

        monitor "Walking now" value: student count each.walking;
        monitor "Arrived at MRT" value: arrived_mrt;
        monitor "Arrived elsewhere" value: arrived_other;
        monitor "Average trip (min)" value: empty(trip_times) ? 0.0 : (mean(trip_times) / 60) with_precision 1;

        // Red = going to MRT, orange = going to another building
        display crowding type: 2d {

            species building;
            species road;
            species student;

            graphics "MRT" {
                draw square(20) at: mrt_target color: rgb("#1C7ED6");
                draw "MRT" at: mrt_target + {15, 5} color: rgb("#1C7ED6");
            }
        }

        // Thicker purple = more students used that road
        display bottlenecks type: 2d {

            species building;
            species road aspect: flow;
        }

        display charts refresh: every(10 #cycles) {

            chart "Students" type: series {
                data "Walking" value: student count each.walking color: rgb("#FF0000");
                data "Arrived at MRT" value: arrived_mrt color: rgb("#1C7ED6");
                data "Arrived elsewhere" value: arrived_other color: rgb("#FF9F1C");
            }
        }
    }
}
