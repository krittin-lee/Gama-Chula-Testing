
model ChulaPedestrian

global {


    // 1. File paths

    shape_file buildings_file <- shape_file("../includes/fangyai_buildings.shp");
    shape_file roads_file <- shape_file("../includes/fangyai_roads.shp");

    geometry shape <- envelope(roads_file);

    graph road_network;


    // Settings

    int number_of_students <- 100;

    float walking_speed <- 1.3;

    int created_students <- 0;

    // Stating

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

        // Generate students
        create student number: number_of_students {

            // Starting position inside a building
            location <- any_location_in(one_of(road));

            // Select a destination
            target <- any_location_in(one_of(building));

            // Set walking speed
            speed <- walking_speed;
        }

        // Check number of created students
        created_students <- length(student);

        write "Buildings loaded: " + length(building);
        write "Roads loaded: " + length(road);
        write "Students created: " + created_students;
    }
}


// BUILDINGS

species building {

    aspect default {

        draw shape
            color: rgb("#D8D2C5")
            border: rgb("#A49E92");
    }
}


species road {

    aspect default {

        draw shape
            color: #black
            width: 6.0;
    }
}


species student skills: [moving] {
    point target;

    reflex choose_destination when: target = nil {
        target <- any_location_in(one_of(building));
    }

    reflex move when: target != nil {
        do goto target: target on: road_network;
        if (location = target) {
            target <- nil;
        }
    }

    aspect default {
        draw circle(5.0) color: #red;
    }
}

// Simulation

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