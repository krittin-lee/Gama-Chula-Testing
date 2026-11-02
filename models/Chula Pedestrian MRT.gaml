
model ChulaPedestrianMRT

global {


    // 1. File paths

    shape_file buildings_file <- shape_file("../includes/fangyai_buildings.shp");

    shape_file roads_file <- shape_file("../includes/fangyai_roads.shp");

    geometry shape <- envelope(roads_file);

    graph road_network;

    // Shared destination
    road southern_road;
    point southern_target;


    // 2. SETTINGS

    int number_of_students <- 100;

    float walking_speed <- 1.3;

    int created_students <- 0;

    // 3. Stating

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

        // Find the southernmost road
        // Smaller Y coordinate = farther south
        southern_road <- road with_min_of (each.location.y);

        // Choose a destination on that road
        southern_target <- any_location_in(southern_road);

        // Generate students
        create student number: number_of_students {

            // Starting position on a random road
            location <- any_location_in(one_of(road));

            // All students share the same destination
            target <- southern_target;

            // Set walking speed
            speed <- walking_speed;
        }

        // Check number of created students
        created_students <- length(student);

        write "Buildings loaded: " + length(building);
        write "Roads loaded: " + length(road);
        write "Students created: " + created_students;
        write "Southern road: " + southern_road;
        write "Southern destination: " + southern_target;
    }
}


// 4. BUILDING

species building {

    aspect default {

        draw shape
            color: rgb("#D8D2C5")
            border: rgb("#A49E92");
    }
}

// 5. ROADS

species road {

    aspect default {

        draw shape
            color: rgb("#000000")
            width: 6.0;
    }
}

// 6. STUDENTS

species student skills: [moving] {

    point target;

    // Move towards the shared destination
    reflex move when: target != nil {

        do goto target: target on: road_network;

        if (location = target) {
            target <- nil;
        }
    }

    aspect default {

        draw circle(5.0)
            color: rgb("#FF0000");
    }
}

// 7. EXPERIMENT

experiment chula_simulation type: gui {

    parameter "Number of students"
        var: number_of_students
        min: 10
        max: 500
        step: 10;

    parameter "Walking speed (m/s)"
        var: walking_speed
        min: 0.5
        max: 3.0
        step: 0.1;

    output {

        display campus_display type: 2d {

            species road;
            species building;
            species student;
        }
    }
}
