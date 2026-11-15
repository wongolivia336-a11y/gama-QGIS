from pathlib import Path
import csv,json,random,re
from collections import Counter
root=Path(__file__).resolve().parents[1]
src=root/'models'/'NoonScope.gaml'; dst=root/'models'/'CampusScopeFullDay.gaml'; inc=root/'includes'
s=src.read_text(encoding='utf-8')
def sub(pattern,repl,flags=0):
 global s
 s,n=re.subn(pattern,repl,s,count=1,flags=flags)
 if n!=1: raise ValueError('match count '+str(n)+' for '+pattern)
sub(r'model NoonScope(?=\s)','model CampusScopeFullDay')
sub(r'float start_minute <- 690\.0;[^\n]*','float start_minute <- 450.0; // 全天从07:30开始，单位为午夜后的分钟数。')
sub(r'float finish_minute <- 810\.0;[^\n]*','float finish_minute <- 1050.0; // 全天在17:30结束。')
sub(r'float now_minute <- start_minute;[^\n]*','float now_minute <- start_minute; // 当前模拟时刻从07:30初始化。')
sub(r"string output_dir <- '../results';","string output_dir <- '../results/full_day';")
sub(r"file population_file <- csv_file\('../includes/population\.csv', true\);","string population_path <- '../includes/population_full_day.csv';\n    file population_file <- csv_file(population_path, true);")
sub(r"string network_path <- '../includes/single_sites/site_1\.json';","string network_path <- '../includes/full_day_network.json';")
sub(r"file buildings_file <- json_file\('../includes/buildings\.geojson'\);","file buildings_file <- json_file('../includes/full_day_buildings.geojson');")
sub(r"file roads_file <- json_file\('../includes/roads\.geojson'\);","file roads_file <- json_file('../includes/full_day_roads.geojson');")
sub(r"file portals_file <- json_file\('../includes/portals\.geojson'\);","file portals_file <- json_file('../includes/full_day_portals.geojson');\n    file map_meta_file <- json_file('../includes/full_day_map_meta.json');")
sub(r'experiment NoonScope type: gui','experiment CampusScopeFullDay type: gui')
sub(r'experiment NoonScopeVerify type: gui','experiment CampusScopeFullDayVerify type: gui')
sub(r"parameter '设施点位（site_1至site_4，baseline为无设施）' var: network_path among: \[[^\n]*","parameter '全天网络配置路径' var: network_path;\n    parameter '人口CSV路径' var: population_path;")
sub(r"assert empty\(student_agents where \(each\.state='walking' or each\.state='not_released'\)\) label: '[^']*';","assert empty(student_agents where (each.state='walking' or each.state='not_released')) label: '17:30仍有人行走或未出发，拒绝宣称行程完成';")
sub(r'reflex coordinate_noon when:','reflex coordinate_full_day when:')
targets=r'''    list<string> activity_building_ids(string activity) {
        list<string> ids <- [];
        string key <- activity='a' ? 'food' : (activity='c' ? 'class' : 'study');
        if network_data contains_key 'activity_buildings' {
            map by_activity <- map(network_data['activity_buildings']);
            if by_activity contains_key key {
                loop raw_id over: list(by_activity[key]) { add string(raw_id) to: ids; }
                return ids;
            }
        }
        if activity='a' { ids <- ['1378']; }
        else if activity='c' { ids <- ['50001','1344']; }
        else if activity='d' { ids <- ['5']; }
        return ids;
    }

    list<string> building_target_nodes(string building_id) {
        list<string> targets <- [];
        if network_data contains_key 'building_entrances' {
            map entrance_map <- map(network_data['building_entrances']);
            if entrance_map contains_key building_id {
                loop raw_node over: list(entrance_map[building_id]) { add string(raw_node) to: targets; }
                if not empty(targets) { return targets; }
            }
        }
        if building_nodes contains_key building_id { add string(building_nodes[building_id]) to: targets; }
        return targets;
    }

    list<string> activity_targets(student person, string activity) {
        list<string> targets <- [];
        if activity='a' or activity='c' or activity='d' {
            loop building_id over: activity_building_ids(activity) {
                loop node_id over: building_target_nodes(building_id) {
                    if not (targets contains node_id) { add node_id to: targets; }
                }
            }
        }
        else if activity='e' { loop raw over: portal_data { add string(map(raw)['node_id']) to: targets; } }
        else if activity='h' { if person.home_node!='' { add person.home_node to: targets; } }
        else { loop raw over: facility_data { add string(map(raw)['node_id']) to: targets; } }
        return targets;
    }

    list<string> reachable_targets(student person, string activity) {
        list<string> eligible <- [];
        loop target over: activity_targets(person,activity) {
            string route_key <- pair_key(person.current_node,target);
            if route_data contains_key route_key {
                list alternatives <- list(route_data[route_key]);
                map shortest <- map(alternatives at 0);
                if now_minute+float(shortest['length_m'])/person.walking_speed_mps/60.0+0.1<finish_minute { add target to: eligible; }
            }
        }
        return eligible;
    }

    float safe_release(string origin, float original, int cohort, float speed) {
'''
sub(r'    list<string> activity_targets\(string activity\) \{.*?    float safe_release\(',targets,re.S)
sub(r'    float safe_release\(string origin, float original, int cohort, float speed\) \{.*?    action hold_at_destination',"""    float safe_release(string origin, float original, int cohort, float speed) {
        return max(start_minute,min(finish_minute-1.0,original));
    }

    action hold_at_destination""",re.S)
chooser=r'''    list<float> activity_weights(float time_minute) {
        if time_minute<510.0 { return [0.05,0.05,0.72,0.15,0.03,0.0]; }
        if time_minute<690.0 { return [0.04,0.08,0.70,0.15,0.03,0.0]; }
        if time_minute<750.0 { return [0.70,0.20,0.0,0.05,0.05,0.0]; }
        if time_minute<790.0 { return [0.20,0.45,0.0,0.30,0.05,0.0]; }
        if time_minute<810.0 { return [0.0,0.05,0.50,0.0,0.45,0.0]; }
        if time_minute<1020.0 { return [0.05,0.10,0.62,0.18,0.05,0.0]; }
        return [0.0,0.0,0.0,0.0,0.0,1.0];
    }

    action choose_next_activity(student person, string reason_text) {
        list<float> weights <- activity_weights(now_minute);
        list<string> activities <- ['a','b','c','d','e','h'];
        loop i from: 0 to: 5 {
            if not (activities[i]='b' and empty(facility_data)) and empty(reachable_targets(person,activities[i])) { weights[i] <- 0.0; }
        }
        float weight_sum <- sum(weights);
        if weight_sum<=0.0 { do hold_at_destination person: person; return; }
        weights <- weights collect (each/weight_sum);
        float draw <- rnd(0.0,1.0);
        string activity <- draw<weights[0] ? 'a' : (draw<weights[0]+weights[1] ? 'b' : (draw<weights[0]+weights[1]+weights[2] ? 'c' : (draw<weights[0]+weights[1]+weights[2]+weights[3] ? 'd' : (draw<weights[0]+weights[1]+weights[2]+weights[3]+weights[4] ? 'e' : 'h'))));
        person.current_activity <- activity;
        if activity='b' and not empty(facility_data) {
            list candidates <- facility_data where (reachable_targets(person,'b') contains string(map(each)['node_id']));
            map selected_facility <- map(one_of(candidates));
            string destination_node <- string(selected_facility['node_id']);
            person.target_facility_id <- int(selected_facility['facility_id']);
            do plan_route person: person to_node: destination_node activity_name: activity reason_text: reason_text;
        }
        else if activity='b' and empty(facility_data) {
            person.state <- 'baseline_rest';
            person.stay_until <- min(finish_minute-30.0,now_minute+20.0);
            person.route_kind <- 'baseline_local'; person.target_node <- person.current_node; person.shortest_length <- 0.0; person.selected_length <- 0.0;
            do write_decision person: person activity_name: activity target_node: person.current_node reason_text: reason_text+'；无设施基线原地休息20分钟';
            do write_event person: person event_name: 'baseline_rest_start' activity_name: '基线原地休息' node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false;
        }
        else if activity='e' or activity='h' {
            string destination_node <- activity='h' ? person.home_node : one_of(reachable_targets(person,'e'));
            do plan_route person: person to_node: destination_node activity_name: activity reason_text: reason_text;
        }
        else {
            string destination_node <- one_of(reachable_targets(person,activity));
            do plan_route person: person to_node: destination_node activity_name: activity reason_text: reason_text;
        }
    }

    action plan_route'''
sub(r'    action choose_next_activity\(student person, string reason_text\) \{.*?    action plan_route',chooser,re.S)
arrival=r'''    action begin_target_stay(student person) {
        if person.current_activity='e' {
            person.state <- 'exited';
            do write_event person: person event_name: 'exit' activity_name: '路过离开校园' node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false;
        }
        else if person.current_activity='h' {
            person.state <- 'exited';
            do write_event person: person event_name: 'return_home' activity_name: '返回晨间起点' node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false;
        }
        else {
            person.state <- person.current_activity='a' ? 'eating' : (person.current_activity='c' ? 'in_class' : 'studying');
            person.stay_until <- min(finish_minute-30.0,now_minute+30.0);
            do write_event person: person event_name: 'building_arrival' activity_name: person.current_activity node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false;
        }
    }

    action move_student'''
sub(r'    action begin_target_stay\(student person\) \{.*?    action move_student',arrival,re.S)
sub(r'(?m)^        seed <- random_seed;.*\n        do load_selected_network;.*$','''        seed <- random_seed;
        map meta <- map(map_meta_file.contents);
        list bounds <- list(meta['bounds']);
        display_min_x <- float(bounds at 0);
        display_max_y <- float(bounds at 3);
        display_width <- float(bounds at 2)-display_min_x;
        display_height <- display_max_y-float(bounds at 1);
        shape <- rectangle(display_width,display_height);
        do load_selected_network; network_data <- map(network_file.contents); node_data <- map(network_data['nodes']); route_data <- map(network_data['routes']); building_nodes <- map(network_data['building_nodes']); portal_data <- list(network_data['portals']); facility_data <- list(network_data['facilities']); scenario_label <- string(network_data['scenario_label']);''')
loop=r'''        loop row_index from: 0 to: total_population-1 {
            int row <- row_index;
            string sid <- string(records[0,row]);
            string major <- string(records[1,row]);
            string origin_kind <- string(records[4,row]);
            string origin_building <- string(records[5,row]);
            string origin_node <- '';
            if origin_kind='building' {
                if network_data contains_key 'building_entrances' {
                    map entrance_map <- map(network_data['building_entrances']);
                    if entrance_map contains_key origin_building {
                        list<string> entrance_nodes <- list(entrance_map[origin_building]);
                        if not empty(entrance_nodes) { origin_node <- string(one_of(entrance_nodes)); }
                    }
                }
                if origin_node='' and building_nodes contains_key origin_building { origin_node <- string(building_nodes[origin_building]); }
            }
            else if origin_kind='east_portal' {
                list east_portals <- portal_data where (bool(map(each)['is_east']));
                assert not empty(east_portals) label: '人口表需要东门，但路网中没有东门portal：'+sid;
                map selected_portal <- map(one_of(east_portals));
                origin_node <- string(selected_portal['node_id']);
            }
            else if origin_kind='campus_portal' {
                assert not empty(portal_data) label: '人口表需要校门portal，但路网中没有portal：'+sid;
                map selected_portal <- map(one_of(portal_data));
                origin_node <- string(selected_portal['node_id']);
            }
            assert node_points contains_key origin_node label: '人口起点缺少道路节点：'+sid+' / '+origin_building;
            create student number: 1 {
                student_id <- sid; major_code <- major; state <- 'not_released';
                release_minute <- max(start_minute,min(finish_minute-1.0,float(records[7,row])));
                walking_speed_mps <- float(records[9,row]); release_cohort <- int(records[8,row]);
                current_node <- origin_node; home_node <- origin_node; target_node <- origin_node;
                location <- world.node_location(origin_node); student_order <- row_index;
                visit_count <- 0; interacted <- false; cross_interacted <- false;
                current_facility_id <- -1; target_facility_id <- -1; current_activity <- '';
                route_nodes <- []; route_index <- 0; route_kind <- 'none';
                shortest_length <- 0.0; selected_length <- 0.0; stay_until <- -1.0; release_checked_1310 <- false;
            }
        }'''
sub(r'(?m)^        loop row_index from: 0 to: total_population-1 \{.*$',loop)
reflex=r'''    reflex coordinate_full_day when: initialized and not finished {
        now_minute <- min(finish_minute,now_minute+step_minutes);
        loop person over: student_agents {
            if person.state='not_released' and now_minute+0.00001>=person.release_minute {
                person.state <- 'walking'; released_total <- released_total+1;
                do choose_next_activity person: person reason_text: '全天按时段行为权重选择活动';
                do write_event person: person event_name: 'release' activity_name: person.current_activity node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false;
            }
        }
        loop person over: student_agents {
            if person.state='walking' { do move_student person: person; }
            else if (person.state='eating' or person.state='studying' or person.state='in_class') and now_minute>=person.stay_until {
                person.state <- 'walking';
                do choose_next_activity person: person reason_text: '停留结束后按全天当前时段重新决策';
            }
            else if person.state='baseline_rest' and now_minute>=person.stay_until {
                person.state <- 'walking';
                do write_event person: person event_name: 'baseline_rest_end' activity_name: '基线原地休息结束' node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false;
                do choose_next_activity person: person reason_text: '基线休息结束后按全天当前时段重新决策';
            }
            else if person.state='facility_rest' and now_minute>=person.stay_until {
                string facility_key <- string(person.current_facility_id);
                facility_occupancy[facility_key] <- max(0,facility_occupancy[facility_key]-1);
                int former_facility <- person.current_facility_id;
                person.current_facility_id <- -1; person.state <- 'walking';
                do write_event person: person event_name: 'facility_rest_end' activity_name: '设施停留结束' node_id: person.current_node facility_id: former_facility partner_id: '' cross_major: false;
                do choose_next_activity person: person reason_text: '设施停留结束后按全天当前时段重新决策';
            }
        }
        do update_facility_counts;
        do update_heatmaps;
        int rounded_minute <- int(now_minute);
        if rounded_minute>last_stat_minute { last_stat_minute <- rounded_minute; do write_minute_statistics; }
        if now_minute>=finish_minute and not finished { do write_final_outputs; initialized <- false; finished <- true; do pause; }
    }'''
sub(r'    reflex coordinate_full_day when: initialized and not finished \{.*?(?=\n\}\s*//)',reflex,re.S)
sub(r"(?m)^    string current_node <- '';.*$","    string current_node <- ''; // 学生当前精确抵达的路网节点。\n    string home_node <- ''; // 晨间宿舍门或校门，作为17:00后的返程目标。",re.M)
s=s.replace('person.stay_until <- now_minute+20.0;','person.stay_until <- min(finish_minute-30.0,now_minute+20.0);',1)
s=s.replace('NOON_MODEL_CHECK','FULL_DAY_MODEL_CHECK').replace('NOON_MODEL_FINISHED','FULL_DAY_MODEL_FINISHED')
s=s.replace('定义11:30至13:30午间校园活动与设施评估模型。','沿用午间原型状态机，扩展为07:30至17:30全天校园活动模型。')
s=s.replace('13:30写最终摘要后关闭协调循环并暂停模型。','17:30写最终摘要后关闭协调循环并暂停模型。')
if any(x in s for x in ['experiment NoonScope type: gui','experiment NoonScopeVerify type: gui','start_minute <- 690.0','finish_minute <- 810.0']): raise ValueError('Noon-only token remains')
dst.write_text(s,encoding='utf-8')

inc.mkdir(parents=True,exist_ok=True)
majors=['ENV','OCEAN','MARX','CHEM','PUBLIC_ADMIN']
labels={'ENV':'环境','OCEAN':'海洋','MARX':'马克思主义','CHEM':'化学','PUBLIC_ADMIN':'公共管理'}
colors={'ENV':'[28,164,94]','OCEAN':'[38,124,221]','MARX':'[150,76,198]','CHEM':'[239,143,38]','PUBLIC_ADMIN':'[220,67,77]'}
origins=[
('dorm','DORM_NW1','西北一楼',108,[30,27,5,26,20]),
('dorm','DORM_NW2','西北二楼（待QGIS核名）',108,[29,28,6,25,20]),
('dorm','DORM_NW3','西北三楼',107,[29,28,6,25,19]),
('dorm','DORM_NW4','西北四楼',107,[29,28,6,25,19]),
('dorm','DORM_NW5','西北五楼',107,[29,28,5,26,19]),
('dorm','DORM_SW1','西南一楼',107,[29,28,5,26,19]),
('dorm','DORM_SW2','西南二楼',107,[29,28,5,26,19]),
('dorm','DORM_SW3','西南三楼',107,[29,28,5,26,19]),
('dorm','DORM_SW7','西南七楼',107,[29,28,5,26,19]),
('dorm','DORM_SW8','西南八楼',107,[29,28,5,25,20]),
('dorm','DORM_SW9','西南九楼',107,[29,28,5,25,20]),
('campus_portal','CAMPUS_GATES','四平路校区校园校门集合',295,[80,77,14,70,54])]
with (inc/'full_day_origin_allocation.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.writer(f); w.writerow(['origin_kind','origin_key','display_name','total_agents',*majors,'source_note'])
 for kind,key,name,total,counts in origins: w.writerow([kind,key,name,total,*counts,'参数表：晨间宿舍80%/校门20%；专业总人数固定；宿舍分栋推导留痕。'])
 totals=[sum(o[4][i] for o in origins) for i in range(5)]
 w.writerow(['TOTAL','ALL','全体',sum(o[3] for o in origins),*totals,'对账：1474人；五专业=400/384/72/351/267。'])
rng=random.Random(20261105); records=[]
for kind,key,name,total,counts in origins:
 for i,major in enumerate(majors):
  for n in range(1,counts[i]+1):
   records.append({'student_id':f'TD-{key}-{major}-{n:04d}','major_code':major,'major_label':labels[major],'color_rgb':colors[major],'origin_kind':'building' if kind=='dorm' else 'campus_portal','origin_building_id':key if kind=='dorm' else '-1','source_group':'dorm' if kind=='dorm' else 'campus_gate','release_minute':'','period_index':0,'walking_speed_mps':''})
if len(records)!=1474: raise ValueError('bad population total')
times=[450+(i+rng.random())*(60/len(records)) for i in range(len(records))]; rng.shuffle(times)
for row,t in zip(records,times): row['release_minute']=f'{t:.5f}'; row['walking_speed_mps']=f'{rng.uniform(1,1.5):.4f}'
rng.shuffle(records)
with (inc/'population_full_day.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(records[0])); w.writeheader(); w.writerows(records)
assert Counter(r['major_code'] for r in records)==Counter({'ENV':400,'OCEAN':384,'MARX':72,'CHEM':351,'PUBLIC_ADMIN':267})
assert Counter(r['source_group'] for r in records)==Counter({'dorm':1179,'campus_gate':295})
profile={'model':'CampusScopeFullDay','window':{'start':'07:30','end':'17:30','start_minute':450,'end_minute':1050},'population':{'total':1474,'major_counts':{'ENV':400,'OCEAN':384,'MARX':72,'CHEM':351,'PUBLIC_ADMIN':267},'origin_split':{'dorms':1179,'campus_gates':295},'dorm_buildings':11,'campus_gate_distribution':'uniform over the actual campus portals in the GIS network','population_seed':20261105,'gama_seed':42,'release_window':{'start':'07:30','end':'08:30','distribution':'stratified uniform with deterministic jitter'}},'activity_order':['eat','rest','class','study','pass_or_exit','return_to_origin'],'time_bands':[{'start':'07:30','end':'08:30','weights':[0.05,0.05,0.72,0.15,0.03,0],'rationale':'晨间到校与首批课程，上课占主导。'},{'start':'08:30','end':'11:30','weights':[0.04,0.08,0.70,0.15,0.03,0],'rationale':'上午课程为主，穿插自习、短休息与少量穿行。'},{'start':'11:30','end':'12:30','weights':[0.70,0.20,0,0.05,0.05,0],'rationale':'沿用旧午间提示词第一时段比例。'},{'start':'12:30','end':'13:10','weights':[0.20,0.45,0,0.30,0.05,0],'rationale':'沿用旧午间提示词第二时段比例。'},{'start':'13:10','end':'13:30','weights':[0,0.05,0.50,0,0.45,0],'rationale':'沿用旧午间提示词第三时段比例；删除13:10强制离开设施分支。'},{'start':'13:30','end':'17:00','weights':[0.05,0.10,0.62,0.18,0.05,0],'rationale':'下午课程为主，增加自习并保留短休息、就餐与穿行。'},{'start':'17:00','end':'17:30','weights':[0,0,0,0,0,1],'rationale':'返回晨间起点；宿舍来源回楼门，校门来源回原校门。'}],'stay_minutes':{'building':30,'facility':20,'baseline_rest':20,'late_day_stays_capped_at':'17:00'},'routing':{'shortest_route_probability':0.8,'detour_probability':0.2,'maximum_detour_ratio':1.25,'walking_speed_mps':[1.0,1.5]},'interpretation':'全天行为比例是可追溯的行为推演规则；课表和QGIS核验到位后，课堂节次、楼栋目的地和楼门路由继续由输入数据细化。'}
(inc/'full_day_activity_profile.json').write_text(json.dumps(profile,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
contract='''# 全天 GAMA 网络输入约定

全天模型从 NoonScope 原型派生。旧示意图只有11栋建筑、5个校门、82段道路，不代表全校区几何。

用户提供的 QGIS 工程已用本机 QGIS 3.44.15 打开。工程列出13个 GeoPackage 图层，但源路径均指向另一台电脑的绝对目录；当前工作区和常用数据目录中没有这些源文件。这是缺少源数据，不是 qgz 格式错误。

核心模拟源文件：research_buildings.gpkg、building_entrances.gpkg、roads.gpkg、nodes.gpkg、model_roads.gpkg、model_nodes.gpkg、interventions.gpkg。
背景显示源文件：other_buildings.gpkg、other_sports.gpkg、sports_fields.gpkg、green_spaces.gpkg、campus_boundary.gpkg、water_bodies.gpkg。

标准化输出：full_day_map_meta.json（范围 [xmin,ymin,xmax,ymax]）、full_day_buildings.geojson、full_day_roads.geojson、full_day_portals.geojson、full_day_network.json。
network JSON 需要 nodes、routes、building_nodes、portals、facilities，并支持 building_entrances（建筑key到多门接入node列表）和 activity_buildings（food/class/study到建筑key列表）。
campus portals 只含校门；楼门是另一层。interventions 要素数以实际图层统计，不预设为192。

宿舍canonical key：DORM_NW1、DORM_NW2、DORM_NW3、DORM_NW4、DORM_NW5、DORM_SW1、DORM_SW2、DORM_SW3、DORM_SW7、DORM_SW8、DORM_SW9。NW2 名称待QGIS核验。
收到GPKG后先核验图层字段、建筑楼门归属、校门数、道路连通与候选点，再生成标准化输入。当前可编译全天模型，但不能用旧午间示意图冒充全校区运行结果。
'''
(inc/'全天网络输入约定.md').write_text(contract,encoding='utf-8')
(root/'results'/'full_day').mkdir(parents=True,exist_ok=True)
print('WROTE',dst)
print('POPULATION',len(records),'MAJORS',dict(Counter(r['major_code'] for r in records)),'ORIGINS',dict(Counter(r['source_group'] for r in records)))
print('RELEASE',min(float(r['release_minute']) for r in records),max(float(r['release_minute']) for r in records))
