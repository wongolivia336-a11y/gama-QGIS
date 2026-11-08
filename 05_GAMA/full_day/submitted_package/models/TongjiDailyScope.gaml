/** Tongji Siping full-day prototype. 07:30–17:30, 1474 synthetic people.
 * Geometry/entrances come from the user's QGIS project. Passive probes do not
 * influence trips. Reference: CampuScope, Charlotte GE; local NoonScope.
 */
model TongjiDailyScope

global {
    file plan_file <- json_file('../includes/daily_plan.json');
    map setup <- map(plan_file.contents);
    map frame <- map(setup['frame']);
    float min_x <- float(frame['min_x']);
    float max_y <- float(frame['max_y']);
    float world_width <- float(frame['width']);
    float world_height <- float(frame['height']);
    geometry shape <- rectangle(world_width,world_height);
    float step <- 10 #second;
    float now_minute <- 450.0;
    int elapsed_steps <- 0;
    float end_minute <- 1050.0;
    int random_seed <- 42;
    bool enable_facilities <- false;
    int selected_site <- 0;
    int selected_person <- 1;
    int render_every_steps <- 1;
    int candidate_heat_reference <- 1474;
    bool show_building_names <- false;
    bool show_probe_codes <- false;
    bool entropy_colors <- false;
    bool export_positions <- false;
    string output_dir <- '../results/live';
    bool initialized <- false;
    bool finished <- false;
    int last_minute <- -1;
    int heat_size <- 80;
    field instant_heat <- field(heat_size,heat_size);
    field diversity_heat <- field(heat_size,heat_size);
    field entropy_heat <- field(heat_size,heat_size);
    field candidate_heat <- field(heat_size,heat_size);
    map routes <- map(setup['routes']);
    map node_observers <- map(setup['node_observers']);
    map<string,road_layer> road_agents <- [];
    map<string,probe> probe_agents <- [];
    map<string,string> building_names <- [];
    map<string,list<int>> grid_counts <- [];
    list<student> persons <- [];
    list<string> major_codes <- ['ENV','OCEAN','MARX','CHEM','PUBLIC_ADMIN'];
    list<string> major_labels <- ['环境','海洋','马克思','化学','公共管理'];
    list<rgb> major_colors <- [rgb(30,160,90),rgb(35,125,225),rgb(160,70,195),rgb(240,145,25),rgb(220,60,80)];
    list<string> state_codes <- ['not_released','dorm','walking','in_class','eating','studying','baseline_rest','facility_rest','waiting_class','walking_break','exited'];
    list<string> state_labels <- ['未入场','宿舍','行走','上课','就餐','自习/科研','户外休息','设施停留','候课','短暂停留','已离校'];
    list<rgb> state_colors <- [#gray,rgb(125,95,70),#blue,#purple,#orange,#cyan,#green,#pink,#yellow,#lightgray,#red];
    list<int> state_counts <- [0,0,0,0,0,0,0,0,0,0,0];
    int total_visits <- 0;
    int cross_events <- 0;
    int route_failures <- 0;
    int late_class_arrivals <- 0;
    int conservation_errors <- 0;
    int max_occupancy <- 0;
    int walking_count <- 0;
    int current_facility_people <- 0;
    int total_observation_events <- 0;
    string clock_text function: string(date([2026,11,8,0,0,0])+now_minute #minute,'HH:mm');
    string mode_text function: enable_facilities ? '设施对比（6人/处）' : '无设施吸引：192点人流观察基线';

    point decode_point(list xy) { return {float(xy at 0)-min_x,max_y-float(xy at 1),0.0}; }
    list<point> decode_points(list coordinates) {
        list<point> points <- []; loop xy over:coordinates { add decode_point(list(xy)) to:points; } return points;
    }
    geometry decode_shape(map geo) {
        string kind <- string(geo['type']); list coords <- list(geo['coordinates']);
        if kind='Point' { return decode_point(coords); }
        if kind='LineString' { return polyline(decode_points(coords)); }
        if kind='Polygon' { geometry poly <- polygon(decode_points(list(coords at 0))); if length(coords)>1 { loop i from:1 to:length(coords)-1 { poly <- poly-polygon(decode_points(list(coords at i))); } } return poly; }
        if kind='MultiPolygon' { geometry all_parts <- nil; loop part over:coords { geometry g <- decode_shape(['type'::'Polygon','coordinates'::part]); all_parts <- all_parts=nil ? g : all_parts+g; } return all_parts; }
        assert false label:'Unsupported GIS geometry: '+kind; return nil;
    }
    string csv_row(list cells) {
        string result <- ''; bool first_cell <- true;
        loop cell over:cells { string text <- cell=nil ? '' : string(cell); result <- result+(first_cell ? '' : ',')+'"'+replace(text,'"','""')+'"'; first_cell <- false; }
        return result+'\n';
    }
    rgb professional_color(string code) { return major_colors at (major_codes index_of code); }
    string state_label(string code) { int i <- state_codes index_of code; return i<0 ? code : state_labels at i; }
    rgb heat_color(float value,float reference) {
        if value<=0 { return rgb(35,43,54); }
        float q <- min(1.0,sqrt(value/reference)); return q<0.6 ? rgb(int(255*q/0.6),int(165*q/0.6),0) : rgb(255,int(165*(1-q)/0.4),0);
    }
    image heat_image(field values,bool diversity,bool historical) {
        matrix<int> pixels <- matrix_with({heat_size,heat_size},int(#black));
        loop x from:0 to:heat_size-1 { loop y from:0 to:heat_size-1 {
            float v <- values[x,y]; if v>0 {
                rgb tone <- heat_color(v,historical ? float(candidate_heat_reference) : 6.0);
                if diversity { tone <- entropy_colors ? heat_color(v,1.0) : (v<1.5 ? rgb(30,95,200) : (v<2.5 ? #cyan : (v<3.5 ? #yellow : (v<4.5 ? #orange : #red)))); }
                pixels[x,y] <- int(tone);
            }
        } }
        return blurred(with_size(image(pixels),480,480),2);
    }
    action change_state(student person,string new_state) {
        if person.state!=new_state {
            add [person.state,person.state_since,now_minute] to:person.timeline;
            save csv_row([person.pid,person.major,person.state,person.state_since,now_minute,person.state_building]) to:output_dir+'/activity_intervals.csv' format:'text' rewrite:false;
            person.state <- new_state; person.state_since <- now_minute; person.state_building <- person.target_building;
        }
    }
    action begin_leg(student person) {
        map job <- map(person.jobs at person.job_index); person.job_index <- person.job_index+1; person.current_job <- job;
        person.target_building <- int(job['building_id']); person.target_node <- int(job['target_node']); person.activity <- string(job['activity']);
        person.route <- map(routes[string(job['route'])]); person.path_points <- decode_points(list(person.route['points']));
        person.progress <- 0.0; person.segment_index <- 1; person.road_cursor <- 0; person.observation_index <- 0; person.facility_index <- 0;
        assert (person.location distance_to (person.path_points at 0))<0.001 label:'Route start differs from actual position: '+string(person.pid);
        do change_state person:person new_state:'walking';
        save csv_row([now_minute,person.pid,person.major,person.activity,person.target_building,person.target_node,person.route['kind'],person.route['shortest'],person.route['length'],job['depart'],job['activity_start'],job['until']]) to:output_dir+'/decisions.csv' format:'text' rewrite:false;
        if float(person.route['length'])<0.00001 { do arrive person:person; }
    }
    action arrive(student person) {
        person.current_node <- person.target_node; person.stay_until <- float(person.current_job['until']);
        string activity <- person.activity;
        if activity='in_class' {
            if now_minute<float(person.current_job['activity_start']) { activity <- 'waiting_class'; }
            else if now_minute>float(person.current_job['activity_start'])+0.2 { late_class_arrivals <- late_class_arrivals+1; }
        }
        do change_state person:person new_state:activity;
    }
    action record_pass(student person,probe site) {
        site.pass_events <- site.pass_events+1; total_observation_events <- total_observation_events+1;
        if not(site.seen_passers contains_key string(person.pid)) { site.seen_passers[string(person.pid)] <- true; site.unique_passers <- site.unique_passers+1; }
    }
    action enter_facility(student person,probe site) {
        add person to:site.occupants; person.current_facility <- site; site.visits <- site.visits+1; total_visits <- total_visits+1;
        if not(site.seen_visitors contains_key string(person.pid)) { site.seen_visitors[string(person.pid)] <- true; site.unique_visitors <- site.unique_visitors+1; }
        person.facility_until <- now_minute+rnd(20.0,40.0);
        max_occupancy <- max(max_occupancy,length(site.occupants)); assert length(site.occupants)<=6 label:'Facility capacity exceeded';
        list<student> partners <- site.occupants where(each!=person);
        if not empty(partners) { student other <- one_of(partners); if other.major!=person.major and flip(0.6) { site.cross_events <- site.cross_events+1; cross_events <- cross_events+1; } }
        do change_state person:person new_state:'facility_rest';
        save csv_row([now_minute,person.pid,site.cid,'enter',length(site.occupants)]) to:output_dir+'/facility_events.csv' format:'text' rewrite:false;
    }
    action move_person(student person) {
        float before <- person.progress; float next_progress <- min(float(person.route['length']),before+person.speed*10.0);
        list events <- list(person.route['observations']);
        if enable_facilities and person.activity!='in_class' {
            list encounters <- list(person.route['facility_encounters']);
            loop while:(person.facility_index<length(encounters)) {
                list ev <- list(encounters at person.facility_index); float enter <- float(ev at 3);
                if enter<0 { person.facility_index <- person.facility_index+1; }
                else if enter>next_progress+0.00001 { break; }
                else {
                    person.facility_index <- person.facility_index+1; probe site <- probe_agents[string(int(ev at 2))];
                    if enter>=before-0.00001 and (selected_site=0 or selected_site=site.cid) {
                        if length(site.occupants)>=6 { site.full_skips <- site.full_skips+1; }
                        else if flip(0.2) { next_progress <- max(before,enter); do enter_facility person:person site:site; break; }
                    }
                }
            }
        }
        loop while:(person.observation_index<length(events)) {
            list ev <- list(events at person.observation_index);
            if float(ev at 0)>next_progress+0.00001 { break; }
            person.observation_index <- person.observation_index+1;
            if float(ev at 1)>=before-0.00001 { do record_pass person:person site:probe_agents[string(int(ev at 2))]; }
        }
        person.progress <- next_progress;
        list cumulative <- list(person.route['cum']);
        loop while:(person.segment_index<length(cumulative) and float(cumulative at person.segment_index)<=next_progress+0.000001) { person.segment_index <- person.segment_index+1; }
        if person.segment_index>=length(person.path_points) { person.location <- last(person.path_points); }
        else {
            point left <- person.path_points at (person.segment_index-1); point right <- person.path_points at person.segment_index;
            float a <- float(cumulative at (person.segment_index-1)); float b <- float(cumulative at person.segment_index);
            float q <- (next_progress-a)/max(0.000001,b-a); person.location <- {left.x+(right.x-left.x)*q,left.y+(right.y-left.y)*q,0.0};
        }
        if person.state='walking' and next_progress>=float(person.route['length'])-0.00001 { do arrive person:person; }
    }
    action count_public_person(student person) {
        int column <- min(heat_size-1,max(0,int(person.location.x/world_width*heat_size)));
        int row <- min(heat_size-1,max(0,int(person.location.y/world_height*heat_size)));
        string key <- string(column)+':'+string(row); list<int> counts <- grid_counts contains_key key ? grid_counts[key] : [0,0,0,0,0];
        int m <- major_codes index_of person.major; counts[m] <- counts[m]+1; grid_counts[key] <- counts;
        if person.state='walking' { instant_heat[column,row] <- instant_heat[column,row]+1; }
    }
    action count_at_probe(student person,probe site) {
        site.current_people <- site.current_people+1; int m <- major_codes index_of person.major;
        site.current_majors[m] <- site.current_majors[m]+1;
        if person.state!='walking' {
            site.observed_rest_person_minutes <- site.observed_rest_person_minutes+10.0/60.0;
            if not(site.seen_stayers contains_key string(person.pid)) { site.seen_stayers[string(person.pid)] <- true; site.unique_observed_stayers <- site.unique_observed_stayers+1; }
        }
    }
    action update_statistics {
        instant_heat <- field(heat_size,heat_size); diversity_heat <- field(heat_size,heat_size); entropy_heat <- field(heat_size,heat_size); candidate_heat <- field(heat_size,heat_size); grid_counts <- [];
        state_counts <- [0,0,0,0,0,0,0,0,0,0,0]; walking_count <- 0; current_facility_people <- 0;
        ask road_layer { current_people <- 0; }
        ask probe { current_people <- 0; current_majors <- [0,0,0,0,0]; }
        loop person over:persons {
            int s <- state_codes index_of person.state; assert s>=0 label:'Unknown state '+person.state; state_counts[s] <- state_counts[s]+1;
            if person.state='walking' {
                walking_count <- walking_count+1; do count_public_person person:person;
                list parts <- list(person.route['road_parts']);
                loop while:(person.road_cursor<length(parts)-1 and person.progress>float(list(parts at person.road_cursor) at 1)+0.00001) { person.road_cursor <- person.road_cursor+1; }
                if not empty(parts) { road_layer road <- road_agents[string(int(list(parts at person.road_cursor) at 2))]; road.current_people <- road.current_people+1; }
                list events <- list(person.route['observations']);
                if person.observation_index>0 { loop k from:0 to:person.observation_index-1 {
                    list ev <- list(events at k);
                    if person.progress>=float(ev at 0)-0.00001 and person.progress<=float(ev at 1)+0.00001 { do count_at_probe person:person site:probe_agents[string(int(ev at 2))]; }
                } }
            }
            else if person.state='baseline_rest' or person.state='walking_break' {
                do count_public_person person:person;
                loop pid over:list(node_observers[string(person.current_node)]) { do count_at_probe person:person site:probe_agents[string(int(pid))]; }
            }
            else if person.state='facility_rest' { current_facility_people <- current_facility_people+1; do count_public_person person:person; do count_at_probe person:person site:person.current_facility; }
        }
        assert sum(state_counts)=1474 label:'Population conservation failed';
        loop key over:grid_counts.keys {
            list<string> xy <- split_with(key,':'); list<int> counts <- grid_counts[key]; int n <- sum(counts); int groups <- 0; float h <- 0.0;
            loop c over:counts { if c>0 { groups <- groups+1; float p <- float(c)/n; h <- h-p*ln(p)/ln(5.0); } }
            diversity_heat[int(xy at 0),int(xy at 1)] <- groups; entropy_heat[int(xy at 0),int(xy at 1)] <- h;
        }
        ask probe {
            groups_now <- current_majors count(each>0); balance_now <- 0.0;
            if current_people>0 { loop c over:current_majors { if c>0 { float p <- float(c)/current_people; balance_now <- balance_now-p*ln(p)/ln(5.0); } } }
            candidate_heat[location] <- candidate_heat[location]+unique_passers;
        }
    }
    action export_statistics {
        save csv_row([clock_text,now_minute]+state_counts+[walking_count,current_facility_people,total_observation_events,total_visits,late_class_arrivals]) to:output_dir+'/states.csv' format:'text' rewrite:false;
        if (int(now_minute)-450) mod 5=0 or finished {
            string records <- '';
            loop site over:probe { records <- records+csv_row([clock_text,now_minute,site.cid,site.unique_passers,site.pass_events,site.current_people,site.groups_now,site.current_people>0 ? site.balance_now : nil,site.unique_observed_stayers,site.observed_rest_person_minutes,enable_facilities ? site.unique_visitors : nil,enable_facilities ? site.visits : nil,enable_facilities ? length(site.occupants) : nil,6,site.full_skips,site.cross_events]); }
            save records to:output_dir+'/candidates.csv' format:'text' rewrite:false;
            string roads_text <- ''; loop road over:road_layer { roads_text <- roads_text+csv_row([clock_text,road.rid,road.current_people,road.current_people/road.length_m,road.length_m]); }
            save roads_text to:output_dir+'/road_instant.csv' format:'text' rewrite:false;
            string cells_text <- ''; loop key over:grid_counts.keys {
                list<string> xy <- split_with(key,':'); list<int> counts <- grid_counts[key]; int x <- int(xy at 0); int y <- int(xy at 1);
                cells_text <- cells_text+csv_row([clock_text,x,y,sum(counts),diversity_heat[x,y],entropy_heat[x,y]]+counts);
            }
            if cells_text!='' { save cells_text to:output_dir+'/diversity_grid.csv' format:'text' rewrite:false; }
            save csv_row([clock_text,now_minute,random_seed,sum(state_counts),walking_count,total_visits,total_observation_events,round((now_minute-450)/6.0)]) to:output_dir+'/heartbeat.csv' format:'text' rewrite:false;
            write 'HEARTBEAT '+clock_text+' people='+string(sum(state_counts))+' moving='+string(walking_count)+' observations='+string(total_observation_events);
        }
        if export_positions {
            string records <- ''; loop person over:persons { records <- records+csv_row([clock_text,person.pid,person.major,person.state,person.location.x+min_x,max_y-person.location.y,person.target_building]); }
            save records to:output_dir+'/positions.csv' format:'text' rewrite:false;
        }
    }
    action finish_outputs {
        string records <- ''; loop person over:persons { records <- records+csv_row([person.pid,person.major,person.state,person.state_since,now_minute,person.state_building]); }
        save records to:output_dir+'/activity_intervals.csv' format:'text' rewrite:false;
        save 'FINISHED people=1474 minute='+string(now_minute)+' observations='+string(total_observation_events)+' visits='+string(total_visits)+' max_occupancy='+string(max_occupancy)+'\n' to:output_dir+'/run.log' format:'text' rewrite:false;
        write 'DAILY_FINISHED '+clock_text+' observations='+string(total_observation_events)+' visits='+string(total_visits)+' max_occupancy='+string(max_occupancy);
    }
    init {
        seed <- random_seed;
        loop file_name over:['green_spaces','water_bodies','sports_fields','other_sports'] {
            map doc <- map(json_file('../includes/gis/'+file_name+'.geojson').contents);
            loop raw over:list(doc['features']) { map f <- map(raw); geometry g <- decode_shape(map(f['geometry'])); create surface_layer number:1 { shape <- g; category <- file_name; } }
        }
        loop file_name over:['other_buildings','research_buildings'] {
            map doc <- map(json_file('../includes/gis/'+file_name+'.geojson').contents);
            loop raw over:list(doc['features']) { map f <- map(raw); map a <- map(f['properties']); geometry g <- decode_shape(map(f['geometry']));
                if file_name='research_buildings' { building_names[string(int(a['id']))] <- string(a['name']); }
                create building_layer number:1 { shape <- g; research <- file_name='research_buildings'; bname <- string(a['name']); }
            }
        }
        map road_doc <- map(json_file('../includes/gis/roads.geojson').contents);
        loop raw over:list(road_doc['features']) { map f <- map(raw); map a <- map(f['properties']); geometry g <- decode_shape(map(f['geometry'])); road_layer created <- nil;
            create road_layer number:1 { shape <- g; rid <- int(a['id']); length_m <- float(a['length_m']); created <- self; } road_agents[string(int(a['id']))] <- created;
        }
        map probe_doc <- map(json_file('../includes/gis/interventions.geojson').contents);
        loop raw over:list(probe_doc['features']) { map f <- map(raw); map a <- map(f['properties']); point p <- decode_point(list(map(f['geometry'])['coordinates'])); probe created <- nil;
            create probe number:1 { location <- p; cid <- int(a['id']); created <- self; } probe_agents[string(int(a['id']))] <- created;
        }
        loop raw over:list(setup['gates']) { map a <- map(raw); point p <- decode_point(list(a['coordinates'])); create gate_layer number:1 { location <- p; gate_name <- string(a['name']); } }
        map entrance_doc <- map(json_file('../includes/gis/entrances.geojson').contents);
        loop raw over:list(entrance_doc['features']) { map f <- map(raw); point p <- decode_point(list(map(f['geometry'])['coordinates'])); create entrance_layer number:1 { location <- p; } }
        loop raw over:list(setup['people']) { map a <- map(raw); list jobs_raw <- list(a['jobs']);
            create student number:1 { pid <- int(a['id']); major <- string(a['major']); speed <- float(a['speed']); current_node <- int(a['home_node']); home_building <- int(a['home_building']); jobs <- jobs_raw;
                map first_route <- map(world.routes[string(map(jobs_raw at 0)['route'])]); location <- world.decode_point(list(list(first_route['points']) at 0));
                state <- home_building>0 ? 'dorm' : 'not_released'; state_since <- 450.0; state_building <- home_building;
            }
        }
        persons <- student as list; assert length(persons)=1474 label:'Wrong population'; assert length(probe)=192 label:'Wrong observation-point count'; assert length(road_layer)=337 label:'Wrong road count';
        save 'clock,minute,not_released,dorm,walking,in_class,eating,studying,baseline_rest,facility_rest,waiting_class,walking_break,exited,walking_check,current_facility_people,observation_events,facility_visits,late_class_arrivals\n' to:output_dir+'/states.csv' format:'text' rewrite:true;
        save 'clock,minute,candidate_id,unique_passers,pass_events,current_observed_people,professional_groups,normalized_shannon,unique_observed_stayers,observed_rest_person_minutes,facility_unique_visitors,facility_visits,facility_current_people,capacity,full_skips,cross_events\n' to:output_dir+'/candidates.csv' format:'text' rewrite:true;
        save 'clock,road_id,current_people,people_per_m,length_m\n' to:output_dir+'/road_instant.csv' format:'text' rewrite:true;
        save 'clock,column,row,current_public_people,professional_groups,normalized_shannon,ENV,OCEAN,MARX,CHEM,PUBLIC_ADMIN\n' to:output_dir+'/diversity_grid.csv' format:'text' rewrite:true;
        save 'person_id,major,state,start_minute,end_minute,building_id\n' to:output_dir+'/activity_intervals.csv' format:'text' rewrite:true;
        save 'minute,person_id,major,activity,building_id,target_node,route_kind,shortest_m,selected_m,planned_depart,activity_start,activity_until\n' to:output_dir+'/decisions.csv' format:'text' rewrite:true;
        save 'minute,person_id,candidate_id,event,current_people\n' to:output_dir+'/facility_events.csv' format:'text' rewrite:true;
        save 'clock,minute,seed,population,walking,facility_visits,observation_events,progress_percent\n' to:output_dir+'/heartbeat.csv' format:'text' rewrite:true;
        save 'clock,person_id,major,state,x_m,y_m,building_id\n' to:output_dir+'/positions.csv' format:'text' rewrite:true;
        save 'DAILY_INITIALIZED people=1474 roads=337 candidates=192 facilities_enabled='+string(enable_facilities)+'\n' to:output_dir+'/run.log' format:'text' rewrite:true;
        initialized <- true; do update_statistics; do export_statistics; last_minute <- 450;
        write 'DAILY_INITIALIZED people=1474 roads=337 candidates=192';
    }
    reflex simulate_day when:initialized and not finished {
        elapsed_steps <- elapsed_steps+1; now_minute <- min(end_minute,450.0+elapsed_steps/6.0);
        loop person over:persons {
            if person.state='facility_rest' and now_minute>=person.facility_until {
                probe site <- person.current_facility; remove person from:site.occupants;
                save csv_row([now_minute,person.pid,site.cid,'leave',length(site.occupants)]) to:output_dir+'/facility_events.csv' format:'text' rewrite:false;
                person.current_facility <- nil; do change_state person:person new_state:'walking';
            }
            if person.state='walking' { do move_person person:person; }
            else if person.state!='facility_rest' and person.state!='exited' {
                if person.state='waiting_class' and now_minute>=float(person.current_job['activity_start']) { do change_state person:person new_state:'in_class'; }
                if person.job_index<length(person.jobs) and now_minute>=person.stay_until and now_minute>=float(map(person.jobs at person.job_index)['depart']) { do begin_leg person:person; }
            }
        }
        do update_statistics;
        if now_minute>=end_minute-0.00001 { now_minute <- end_minute; finished <- true; }
        if int(now_minute+0.00001)>last_minute { last_minute <- int(now_minute+0.00001); do export_statistics; }
        if finished { do finish_outputs; do pause; }
    }
}

species student {
    int pid; string major; string state; string activity <- ''; float speed; int home_building; int current_node; int target_node; int target_building <- 0; int state_building <- 0;
    list jobs <- []; int job_index <- 0; map current_job <- []; map route <- []; list<point> path_points <- []; float progress <- 0.0;
    int segment_index <- 1; int road_cursor <- 0; int observation_index <- 0; int facility_index <- 0; float stay_until <- 450.0; float state_since <- 450.0;
    list timeline <- []; probe current_facility <- nil; float facility_until <- 0.0;
    aspect base { if state!='not_released' and state!='exited' and state!='dorm' and state!='in_class' and state!='studying' and state!='eating' and state!='waiting_class' {
        draw circle(2.0) color:world.professional_color(major) border:#black;
        if pid=world.selected_person { draw circle(5.0) color:rgb(255,255,255,0) border:#red; }
    } }
}
species building_layer {
    bool research <- false; string bname <- '';
    aspect base { draw shape color:(research ? rgb(244,180,40) : rgb(218,218,214)) border:rgb(160,160,155); if world.show_building_names and research { draw bname at:location color:#black font:font('Microsoft YaHei',9); } }
    aspect dark { draw shape color:rgb(37,45,54) border:rgb(75,85,93); }
}
species surface_layer {
    string category;
    aspect base { draw shape color:(category='green_spaces' ? rgb(178,220,146) : (category='water_bodies' ? rgb(91,172,216) : rgb(245,151,153))) border:rgb(170,175,160); }
}
species gate_layer { string gate_name; aspect base { draw square(5) color:#yellow border:#black; } }
species entrance_layer { aspect base { draw square(3) color:rgb(20,165,135) border:#white; } }
species road_layer {
    int rid; float length_m; int current_people <- 0;
    aspect base { draw shape color:rgb(60,66,72) width:1.0; }
    aspect dark { draw shape color:rgb(70,80,90) width:0.6; }
    aspect density { draw shape color:world.heat_color(current_people/length_m,0.25) width:(current_people>0 ? 2.0 : 0.6); }
}
species probe {
    int cid; int unique_passers <- 0; int pass_events <- 0; int current_people <- 0; list<int> current_majors <- [0,0,0,0,0]; int groups_now <- 0; float balance_now <- 0.0;
    int visits <- 0; int unique_visitors <- 0; int unique_observed_stayers <- 0; float observed_rest_person_minutes <- 0.0; int full_skips <- 0; int cross_events <- 0;
    map<string,bool> seen_passers <- []; map<string,bool> seen_visitors <- []; map<string,bool> seen_stayers <- []; list<student> occupants <- [];
    aspect observe { draw circle(3) color:rgb(130,90,170) border:#white; if world.show_probe_codes { draw 'C'+string(cid) at:location+{4,0} color:#black font:font('Microsoft YaHei',8); } }
    aspect cumulative { bool active <- world.enable_facilities and (world.selected_site=0 or world.selected_site=cid); draw circle(5) color:(active ? world.heat_color(unique_visitors,100.0) : #gray) border:#white; if active and unique_visitors>0 { draw string(unique_visitors)+'人' at:location+{6,0} color:#black font:font('Microsoft YaHei',8); } }
    aspect current { bool active <- world.enable_facilities and (world.selected_site=0 or world.selected_site=cid); draw circle(5) color:(active ? world.heat_color(length(occupants),6.0) : #gray) border:#white; if active and not empty(occupants) { draw string(length(occupants))+'/6' at:location+{6,0} color:#black font:font('Microsoft YaHei',8); } }
    aspect historical { draw circle(6) color:world.heat_color(unique_passers,float(world.candidate_heat_reference)) border:#white; if world.show_probe_codes { draw 'C'+string(cid)+':'+string(unique_passers) at:location+{6,0} color:#white font:font('Microsoft YaHei',8); } }
}

experiment TongjiDailyScope type:gui {
    float minimum_cycle_duration <- 0.02;
    parameter '最小显示周期（秒）' var:minimum_cycle_duration min:0.0 max:2.0;
    parameter '启用设施对比（默认关闭，基线只观察）' var:enable_facilities;
    parameter '设施点编号（0=全部192点）' var:selected_site min:0 max:192;
    parameter '查看人员编号' var:selected_person min:1 max:1474;
    parameter '显示刷新间隔（步，1步=10秒）' var:render_every_steps min:1 max:60;
    parameter '候选点色阶上限（人数）' var:candidate_heat_reference min:1 max:1474;
    parameter '建筑名称' var:show_building_names;
    parameter '候选点编号' var:show_probe_codes;
    parameter '多样性使用均衡指数（否则专业种类数）' var:entropy_colors;
    parameter '导出所有人每分钟位置' var:export_positions;
    parameter '随机种子' var:random_seed;
    parameter '输出文件夹' var:output_dir;
    output {
        layout #stack tabs:true parameters:true navigator:true consoles:true;
        display '1 各专业人员移动' type:java2D refresh:(elapsed_steps mod render_every_steps=0) {
            species surface_layer aspect:base; species building_layer aspect:base; species road_layer aspect:base; species gate_layer aspect:base; species entrance_layer aspect:base; species probe aspect:observe; species student aspect:base;
            graphics Legend { draw clock_text+'  '+mode_text at:{20,20} color:#black font:font('Microsoft YaHei',13); loop i from:0 to:4 { draw (major_labels at i) at:{20,45+i*20} color:(major_colors at i) font:font('Microsoft YaHei',11); } }
        }
        display '2 道路瞬时热力图' type:java2D refresh:(elapsed_steps mod render_every_steps=0) background:#black {
            graphics Heat { draw heat_image(instant_heat,false,false) at:{world_width/2,world_height/2} size:{world_width,world_height}; }
            species road_layer aspect:density; species building_layer aspect:dark;
            graphics Clock { draw clock_text+'  当前道路行走人数（非累计）' at:{20,20} color:#white font:font('Microsoft YaHei',13); draw '热场按当前人数；路段颜色按人数/米。平滑仅用于显示。' at:{20,45} color:#white; }
        }
        display '3 设施累计到访人数' type:java2D refresh:(elapsed_steps mod render_every_steps=0) {
            species surface_layer aspect:base; species building_layer aspect:base; species road_layer aspect:base; species probe aspect:cumulative;
            graphics Status { draw clock_text+'  '+(enable_facilities ? '累计独立访客；人次另存CSV' : '观察基线：未启用设施，设施使用统计不适用') at:{20,20} color:#black font:font('Microsoft YaHei',13); }
        }
        display '4 活动状态折线图' type:java2D refresh:(elapsed_steps mod render_every_steps=0) {
            chart '1474名Agent互斥状态' type:series x_serie_labels:clock_text {
                data '未入场' value:(state_counts at 0) color:#gray; data '宿舍' value:(state_counts at 1) color:rgb(125,95,70); data '行走' value:(state_counts at 2) color:#blue;
                data '上课' value:(state_counts at 3) color:#purple; data '就餐' value:(state_counts at 4) color:#orange; data '自习/科研' value:(state_counts at 5) color:#cyan;
                data '户外休息' value:(state_counts at 6) color:#green; data '设施停留' value:(state_counts at 7) color:#pink; data '候课' value:(state_counts at 8) color:#yellow;
                data '短暂停留' value:(state_counts at 9) color:#lightgray; data '已离校' value:(state_counts at 10) color:#red;
            }
        }
        display '5 学科多样性热力图' type:java2D refresh:(elapsed_steps mod render_every_steps=0) background:#black {
            graphics Heat { draw heat_image(entropy_colors ? entropy_heat : diversity_heat,true,false) at:{world_width/2,world_height/2} size:{world_width,world_height}; }
            species road_layer aspect:dark; species building_layer aspect:dark;
            graphics Clock { draw clock_text+'  '+(entropy_colors ? '专业均衡度 H/log(5)，0—1' : '当前公共空间专业种类数：1蓝/2青/3黄/4橙/5红') at:{20,20} color:#white font:font('Microsoft YaHei',12); draw '空格不表示有人；每格人数与候选点样本量另存。' at:{20,45} color:#white; }
        }
        display '6 设施瞬时人数图' type:java2D refresh:(elapsed_steps mod render_every_steps=0) {
            species surface_layer aspect:base; species building_layer aspect:base; species road_layer aspect:base; species probe aspect:current;
            graphics Status { draw clock_text+'  '+(enable_facilities ? '实际正在停留的人数 / 6座；路过不计占用' : '观察基线：未启用设施，占用人数不适用') at:{20,20} color:#black font:font('Microsoft YaHei',12); }
        }
        display '7 均匀候选点累计热量图' type:java2D refresh:(elapsed_steps mod render_every_steps=0) background:#black {
            graphics Heat { draw heat_image(candidate_heat,false,true) at:{world_width/2,world_height/2} size:{world_width,world_height}; }
            species road_layer aspect:dark; species building_layer aspect:dark; species probe aspect:historical;
            graphics Clock { draw clock_text+'  192点累计去重经过人数；沿路网10m观察' at:{20,20} color:#white font:font('Microsoft YaHei',13); draw '色阶0—'+string(candidate_heat_reference)+'人，暖色更高；同一人重复经过只计1人。' at:{20,45} color:#white; }
        }
        display '个人活动时间轴' type:java2D refresh:(elapsed_steps mod render_every_steps=0) {
            graphics Timeline {
                student person <- persons at (selected_person-1);
                draw '人员 '+string(person.pid)+'  '+(major_labels at (major_codes index_of person.major))+'  当前：'+state_label(person.state)+'  '+clock_text at:{25,35} color:#black font:font('Microsoft YaHei',16);
                draw '下一/当前目的地：'+(person.target_building>0 ? building_names[string(person.target_building)] : '道路或校门') at:{25,70} color:#black font:font('Microsoft YaHei',12);
                loop interval over:(person.timeline+[[person.state,person.state_since,now_minute]]) {
                    list row <- list(interval); float a <- float(row at 1); float b <- float(row at 2); int code <- state_codes index_of string(row at 0);
                    float x <- 40+(a-450)/600*(world_width-80); float width <- max(0.5,(b-a)/600*(world_width-80));
                    draw rectangle(width,45) at:{x+width/2,180+code*58} color:(state_colors at code) border:#white;
                }
                loop i from:0 to:length(state_codes)-1 { draw (state_labels at i) at:{20,180+i*58} color:#black font:font('Microsoft YaHei',11); }
                loop h from:0 to:10 { draw string(date([2026,11,8,7,30,0])+h #hour,'HH:mm') at:{40+h/10.0*(world_width-80),130} color:#black font:font('Microsoft YaHei',9); }
            }
        }
    }
}

experiment Verify type:gui {
    float minimum_cycle_duration <- 0.0;
    parameter 'enable_facilities' var:enable_facilities;
    parameter 'selected_site' var:selected_site;
    parameter 'random_seed' var:random_seed;
    parameter 'output_dir' var:output_dir;
    parameter 'export_positions' var:export_positions;
    output { monitor 'Population' value:sum(state_counts); monitor 'Walking' value:walking_count; monitor 'Observation events' value:total_observation_events; monitor 'Facility visits' value:total_visits; }
}
