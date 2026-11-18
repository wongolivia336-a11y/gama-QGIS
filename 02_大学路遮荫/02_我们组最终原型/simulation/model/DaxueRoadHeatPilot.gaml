model daxue_road_heat_pilot

global {
    float road_length_m <- 262.821;
    float road_width_m <- 38.0;
    geometry world_shape <- rectangle(road_length_m, road_width_m);

    float sim_time_s <- 0.0;
    float step_seconds <- 5.0;
    float step_duration <- step_seconds #second;
    float duration_s <- 21600.0;
    int cohort_size <- 96;
    string weather_date <- '2020-08-13';

    float candidate_s <- 135.0;
    float device_side <- 1.0;
    float lane_offset_m <- 6.5;
    float device_length_m <- 8.0;
    float device_span_m <- 4.6;
    float device_height_m <- 2.7;
    float person_target_height_m <- 1.1;
    int seat_capacity <- 4;

    float rest_seek_share <- 0.15;
    float route_share_nw <- 0.50;
    float pause_acceptance <- 0.55;
    float heat_sensitivity_min <- 0.5;
    float heat_sensitivity_max <- 1.5;
    float tree_radius_m <- 3.5;
    float tree_merge_gap_m <- 4.0;

    bool trace_enabled <- false;
    int trace_frame <- 0;
    float trace_interval_s <- 30.0;
    float last_trace_s <- 0.0;
    bool summary_written <- false;
    int device_occupancy <- 0;
    int device_visits <- 0;
    int completed_trips <- 0;
    float person_time_h <- 0.0;
    float shortwave_dose_wh_m2_person <- 0.0;
    float unshaded_person_min <- 0.0;
    float tree_shaded_person_min <- 0.0;
    float device_shaded_person_min <- 0.0;
    float extra_shade_wh_m2_person <- 0.0;
    float rest_person_min <- 0.0;

    string summary_file <- '../results/gama_site_comparison.csv';
    string trace_file <- '../results/gama_midpoint_trace.csv';

    list<float> tree_nw_start <- [24.3, 149.7];
    list<float> tree_nw_end <- [119.6, 249.1];
    list<float> tree_se_start <- [24.4, 39.8, 150.5];
    list<float> tree_se_end <- [31.4, 109.3, 247.3];

    list<float> air_temperature <- [34.2, 34.7, 34.9, 36.1, 36.2, 36.1, 35.5];
    list<float> relative_humidity <- [63.0, 62.0, 61.0, 56.0, 56.0, 57.0, 60.0];
    list<float> wind_10m <- [4.55, 4.52, 4.33, 3.91, 3.72, 3.83, 3.91];
    list<float> ghi <- [702.0, 824.0, 887.0, 885.0, 816.0, 702.0, 535.0];
    list<float> direct_radiation <- [556.0, 667.0, 724.0, 723.0, 658.0, 559.0, 411.0];
    list<float> diffuse_radiation <- [146.0, 157.0, 163.0, 162.0, 158.0, 143.0, 124.0];
    list<float> solar_altitude <- [58.1824, 68.6643, 73.4887, 68.3964, 57.8219, 45.5910, 32.8635];
    list<float> solar_azimuth <- [114.3502, 137.2875, 180.7215, 223.5637, 246.0310, 258.7683, 267.8086];
    list<float> shadow_along_axis <- [0.6783, 0.2154, -0.1874, -0.5793, -1.0064, -1.5369, -2.3220];
    list<float> shadow_nw <- [0.7248, 0.5867, 0.4357, 0.2566, 0.0250, -0.3075, -0.8615];

    int hour_index -> sim_time_s >= duration_s ? 6 : int(sim_time_s / 3600.0);
    float current_air_temperature -> air_temperature at hour_index;
    float current_relative_humidity -> relative_humidity at hour_index;
    float current_wind_10m -> wind_10m at hour_index;
    float current_ghi -> ghi at hour_index;
    float current_direct -> direct_radiation at hour_index;
    float current_diffuse -> diffuse_radiation at hour_index;
    float current_solar_altitude -> solar_altitude at hour_index;
    float current_solar_azimuth -> solar_azimuth at hour_index;
    float current_shadow_s -> shadow_along_axis at hour_index;
    float current_shadow_nw -> shadow_nw at hour_index;
    string panel_state -> current_ghi >= 750.0 ? 'CLOSED' : (current_ghi >= 500.0 ? 'ANGLED' : 'OPEN');
    float panel_direct_transmittance -> panel_state = 'CLOSED' ? 0.10 : (panel_state = 'ANGLED' ? 0.20 : 0.45);
    float panel_diffuse_factor -> panel_state = 'CLOSED' ? 0.55 : (panel_state = 'ANGLED' ? 0.72 : 0.90);
    float full_shortwave -> current_direct + current_diffuse;

    bool tree_shade(float chainage, float route_side) {
        list<float> starts <- route_side > 0.0 ? tree_nw_start : tree_se_start;
        list<float> ends <- route_side > 0.0 ? tree_nw_end : tree_se_end;
        bool shaded <- false;
        loop i from: 0 to: length(starts) - 1 {
            bool after_start <- chainage >= (starts at i);
            bool before_end <- chainage <= (ends at i);
            if after_start {
                if before_end { shaded <- true; }
            }
        }
        return shaded;
    }

    bool device_shade(float chainage, float lateral) {
        bool covered <- false;
        if candidate_s >= 0.0 {
            float shade_s <- candidate_s + current_shadow_s;
            float shade_nw <- 19.0 + device_side * lane_offset_m + current_shadow_nw;
            bool within_length <- abs(chainage - shade_s) <= device_length_m / 2.0;
            bool within_span <- abs(lateral - shade_nw) <= device_span_m / 2.0;
            if within_length {
                if within_span { covered <- true; }
            }
        }
        return covered;
    }

    float tree_shortwave {
        return current_direct * 0.30 + current_diffuse * 0.65;
    }

    float device_shortwave {
        return current_direct * panel_direct_transmittance + current_diffuse * panel_diffuse_factor;
    }

    float current_shortwave(bool under_tree, bool under_device) {
        float baseline <- under_tree ? tree_shortwave() : full_shortwave;
        if under_device { baseline <- min(baseline, device_shortwave()); }
        return baseline;
    }

    string csv_record(list cells) {
        string result <- '';
        bool first <- true;
        loop cell over: cells {
            result <- result + (first ? '' : ',') + string(cell);
            first <- false;
        }
        return result + '\n';
    }

    init {
        create pedestrian number: cohort_size {
            agent_id <- length(pedestrian) - 1;
            activity_class <- flip(rest_seek_share) ? 'short_pause' : 'through';
            direction <- flip(0.5) ? 1 : -1;
            route_side <- flip(route_share_nw) ? 1.0 : -1.0;
            speed_m_s <- rnd(0.8, 1.4);
            heat_sensitivity <- rnd(heat_sensitivity_min, heat_sensitivity_max);
            arrival_seconds <- rnd(duration_s - 1200.0);
            wants_pause <- false;
            if activity_class = 'short_pause' {
                wants_pause <- flip(min(0.95, pause_acceptance * heat_sensitivity));
            }
            dwell_seconds <- rnd(300.0, 900.0);
            location <- {-10.0, -10.0, 0.0};
        }
    }

    reflex advance_clock {
        if sim_time_s < duration_s { sim_time_s <- sim_time_s + step_seconds; }
    }

    reflex write_trace {
        if trace_enabled {
            if sim_time_s - last_trace_s >= trace_interval_s {
                trace_frame <- trace_frame + 1;
                loop person over: pedestrian {
                    bool active_person <- person.state = 'walking';
                    if person.state = 'resting' { active_person <- true; }
                    if active_person {
                        bool on_tree <- tree_shade(person.progress_m, person.route_side);
                        bool on_device <- device_shade(person.progress_m, 19.0 + person.route_side * lane_offset_m);
                        save csv_record([weather_date, trace_frame, sim_time_s, person.agent_id, person.activity_class, person.state, person.progress_m, person.route_side, current_air_temperature, current_relative_humidity, current_wind_10m, current_ghi, current_direct, current_diffuse, current_solar_altitude, current_solar_azimuth, panel_state, on_tree, on_device]) to: trace_file format: 'text' rewrite: false;
                    }
                }
                last_trace_s <- sim_time_s;
            }
        }
    }

    reflex write_summary {
        if sim_time_s >= duration_s {
            if !summary_written {
                float mean_shortwave_w_m2 <- person_time_h > 0.0 ? shortwave_dose_wh_m2_person / person_time_h : 0.0;
                save csv_record([weather_date, candidate_s, candidate_s < 0.0 ? 'BASELINE' : (candidate_s = 65.0 ? 'A' : (candidate_s = 135.0 ? 'B' : 'C')), seed, cohort_size, rest_seek_share, route_share_nw, completed_trips, device_visits, rest_person_min, person_time_h, unshaded_person_min, tree_shaded_person_min, device_shaded_person_min, extra_shade_wh_m2_person, shortwave_dose_wh_m2_person, mean_shortwave_w_m2]) to: summary_file format: 'text' rewrite: false;
                summary_written <- true;
            }
        }
    }
}

species pedestrian {
    int agent_id <- -1;
    string activity_class <- 'through';
    string state <- 'queued';
    int direction <- 1;
    float route_side <- 1.0;
    float speed_m_s <- 1.0;
    float heat_sensitivity <- 1.0;
    float arrival_seconds <- 0.0;
    float dwell_seconds <- 0.0;
    float dwell_remaining_s <- 0.0;
    float progress_m <- 0.0;
    bool wants_pause <- false;
    bool has_rest_once <- false;

    reflex release_and_move {
        if state = 'queued' {
            if sim_time_s >= arrival_seconds {
                state <- 'walking';
                progress_m <- direction = 1 ? 0.0 : road_length_m;
                location <- {progress_m, 19.0 + route_side * lane_offset_m, 0.0};
            }
        }

        if state = 'walking' {
            float old_s <- progress_m;
            float next_s <- progress_m + direction * speed_m_s * step_seconds;
            bool crosses_device <- false;
            if candidate_s >= 0.0 {
                if direction = 1 {
                    if old_s <= candidate_s {
                        if next_s >= candidate_s { crosses_device <- true; }
                    }
                }
                if direction = -1 {
                    if old_s >= candidate_s {
                        if next_s <= candidate_s { crosses_device <- true; }
                    }
                }
            }
            bool on_device_route <- route_side = device_side;
            bool can_rest <- false;
            if crosses_device {
                if wants_pause {
                    if !has_rest_once {
                        if on_device_route {
                            if device_occupancy < seat_capacity { can_rest <- true; }
                        }
                    }
                }
            }
            if can_rest {
                state <- 'resting';
                progress_m <- candidate_s;
                dwell_remaining_s <- dwell_seconds;
                has_rest_once <- true;
                device_occupancy <- device_occupancy + 1;
                device_visits <- device_visits + 1;
            } else {
                progress_m <- next_s;
            }
            location <- {progress_m, 19.0 + (state = 'resting' ? device_side : route_side) * lane_offset_m, 0.0};
            bool outside_road <- progress_m < 0.0;
            if progress_m > road_length_m { outside_road <- true; }
            if outside_road {
                state <- 'done';
                completed_trips <- completed_trips + 1;
                location <- {-10.0, -10.0, 0.0};
            }
        }

        if state = 'resting' {
            dwell_remaining_s <- dwell_remaining_s - step_seconds;
            rest_person_min <- rest_person_min + step_seconds / 60.0;
            if dwell_remaining_s <= 0.0 {
                state <- 'walking';
                device_occupancy <- max(0, device_occupancy - 1);
                location <- {progress_m, 19.0 + route_side * lane_offset_m, 0.0};
            }
        }

        bool active_for_heat <- state = 'walking';
        if state = 'resting' { active_for_heat <- true; }
        if active_for_heat {
            bool on_tree <- world.tree_shade(progress_m, route_side);
            bool on_device <- world.device_shade(progress_m, 19.0 + route_side * lane_offset_m);
            float current_sw <- world.current_shortwave(on_tree, on_device);
            float baseline_sw <- on_tree ? world.tree_shortwave() : full_shortwave;
            float dt_h <- step_seconds / 3600.0;
            person_time_h <- person_time_h + dt_h;
            shortwave_dose_wh_m2_person <- shortwave_dose_wh_m2_person + current_sw * dt_h;
            if on_tree { tree_shaded_person_min <- tree_shaded_person_min + step_seconds / 60.0; }
            if on_device { device_shaded_person_min <- device_shaded_person_min + step_seconds / 60.0; }
            bool unshaded <- !on_tree;
            if on_device { unshaded <- false; }
            if unshaded { unshaded_person_min <- unshaded_person_min + step_seconds / 60.0; }
            if on_device { extra_shade_wh_m2_person <- extra_shade_wh_m2_person + max(0.0, baseline_sw - current_sw) * dt_h; }
        }
    }

    aspect pedestrian_aspect {
        if state = 'walking' { draw circle(0.9) color: rgb(47, 111, 109); }
        if state = 'resting' { draw circle(1.2) color: rgb(211, 109, 67); }
    }
}

experiment PilotPreview type: gui {
    float seed <- 42.0;
    parameter 'Candidate chainage from northeast (m)' var: candidate_s init: 140.0 min: -1.0 max: 260.0 step: 5.0;
    parameter 'Short-pause share (scenario)' var: rest_seek_share init: 0.15 min: 0.05 max: 0.25 step: 0.05;
    parameter 'NW route share (scenario)' var: route_share_nw init: 0.50 min: 0.35 max: 0.65 step: 0.05;
    output {
        display 'Daxue Road heat pilot' type: java2D {
            graphics 'Base map' {
                draw rectangle(road_length_m, road_width_m) at: {road_length_m / 2.0, 19.0} color: rgb(242, 240, 232) border: rgb(90, 100, 92);
                draw rectangle(road_length_m, 10.0) at: {road_length_m / 2.0, 19.0} color: rgb(218, 219, 214);
                draw rectangle(road_length_m, 0.15) at: {road_length_m / 2.0, 19.0} color: rgb(255, 255, 255);
                loop i from: 0 to: length(tree_nw_start) - 1 {
                    draw rectangle((tree_nw_end at i) - (tree_nw_start at i), 2.0) at: {((tree_nw_end at i) + (tree_nw_start at i)) / 2.0, 19.0 + lane_offset_m} color: rgb(164, 194, 162);
                }
                loop i from: 0 to: length(tree_se_start) - 1 {
                    draw rectangle((tree_se_end at i) - (tree_se_start at i), 2.0) at: {((tree_se_end at i) + (tree_se_start at i)) / 2.0, 19.0 - lane_offset_m} color: rgb(164, 194, 162);
                }
                if candidate_s >= 0.0 {
                    draw rectangle(device_length_m, device_span_m) at: {candidate_s + current_shadow_s, 19.0 + device_side * lane_offset_m + current_shadow_nw} color: rgb(235, 211, 147) border: rgb(164, 123, 65);
                    draw rectangle(device_length_m, 1.0) at: {candidate_s, 19.0 + device_side * lane_offset_m} color: rgb(160, 109, 73);
                }
                draw string(weather_date+'  '+string(10 + int(sim_time_s / 3600.0))+':00  |  Ta '+string(current_air_temperature)+' C  |  GHI '+string(current_ghi)+' W/m2  |  panels '+panel_state) at: {4.0, 35.0} color: rgb(35, 51, 43);
            }
            species pedestrian aspect: pedestrian_aspect;
        }
        monitor 'Simulated minutes' value: sim_time_s / 60.0;
        monitor 'Device visits (synthetic cohort)' value: device_visits;
        monitor 'Additional shade proxy (Wh/m2-person)' value: extra_shade_wh_m2_person;
    }
}

experiment SiteComparison type: batch repeat: 3 keep_seed: true until: summary_written {
    float seed <- 42.0;
    parameter 'Candidate chainage (m)' var: candidate_s among: [-1.0, 65.0, 135.0, 200.0];
    parameter 'Short-pause share' var: rest_seek_share among: [0.05, 0.15, 0.25];
    parameter 'NW route share' var: route_share_nw among: [0.35, 0.50, 0.65];
}

experiment RouteShareSensitivity type: batch repeat: 3 keep_seed: true until: summary_written {
    float seed <- 42.0;
    parameter 'Candidate chainage (m)' var: candidate_s init: 135.0;
    parameter 'Short-pause share' var: rest_seek_share among: [0.05, 0.15, 0.25];
    parameter 'NW route share' var: route_share_nw among: [0.35, 0.50, 0.65];
}

experiment TraceReplay type: batch repeat: 1 keep_seed: true until: summary_written {
    float seed <- 42.0;
    parameter 'Candidate chainage (m)' var: candidate_s init: 135.0;
    parameter 'Short-pause share' var: rest_seek_share init: 0.15;
    parameter 'NW route share' var: route_share_nw init: 0.50;
    parameter 'Trace enabled' var: trace_enabled init: true;
}
