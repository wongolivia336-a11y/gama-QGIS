model NoonScope // 定义11:30至13:30午间校园活动与设施评估模型。

global { // 集中管理输入、状态更新、统计写出和五个可视化窗口。
    int total_population <- 1474; // 固定人口数来自已冻结的人口配置。
    int random_seed <- 42; // 固定随机种子，保证路线和活动选择可复现。
    float start_minute <- 690.0; // 模拟从11:30开始，单位为午夜后的分钟数。
    float finish_minute <- 810.0; // 模拟在13:30结束。
    float step_seconds <- 2.0; // 每个模型步代表真实两秒。
    float step <- step_seconds #second; // 将两秒绑定到GAMA引擎的真实模拟步长。
    float step_minutes <- step_seconds / 60.0; // 将两秒换算为分钟供时钟推进。
    float now_minute <- start_minute; // 当前模拟时刻，初始化为11:30。
    float display_min_x <- -2.482; // 完整图幅最小CAD横坐标，用于转成从零开始的显示坐标。
    float display_max_y <- 502.999; // 完整图幅最大CAD纵坐标，用于上下翻转显示坐标。
    float display_width <- 924.652; // 地图宽度等于最大横坐标减最小横坐标。
    float display_height <- 554.592; // 地图高度等于最大纵坐标减最小纵坐标。
    geometry shape <- rectangle(display_width, display_height); // 将GAMA世界设为正坐标矩形，避免CAD负坐标裁切。
    string output_dir <- '../results'; // 结果表写入项目结果目录。
    bool export_trace <- false; // 默认关闭逐步轨迹，避免结果文件过大。
    int trace_limit <- 20; // 开启逐步轨迹时最多记录前20名学生。
    bool initialized <- false; // 标记初始化完成，避免提前进入主循环。
    bool finished <- false; // 标记模拟已完成，防止引擎结束时重复写出。
    int n_not_released <- 1474; // 保存分钟快照中的未出场人数供图表安全读取。
    int n_walking <- 0; // 保存行走人数，图表不直接遍历正在销毁的种群。
    int n_eating <- 0; // 保存吃饭人数。
    int n_studying <- 0; // 保存自习人数。
    int n_class <- 0; // 保存上课人数。
    int n_facility_rest <- 0; // 保存设施休息人数。
    int n_baseline_rest <- 0; // 保存无设施对照的原地休息人数。
    int n_destination_wait <- 0; // 单独记录已到达后停止新行程的等待人数。
    int n_exited <- 0; // 保存已经离开的人数。
    int last_stat_minute <- -1; // 记录最后写统计的整分钟数，确保每分钟一行。
    int released_total <- 0; // 累计已出场学生数。
    int visit_total <- 0; // 累计设施访问人次。
    int unique_visitors_total <- 0; // 累计至少访问一次设施的独立学生数。
    int interaction_attempts <- 0; // 累计同处设施的不同学生配对机会数。
    int cross_interaction_events <- 0; // 累计跨学科交互事件次数，同一事件只记一次。
    int minute_interaction_events <- 0; // 最近一分钟统计区间内发生的交互事件数。
    int minute_cross_interaction_events <- 0; // 最近一分钟统计区间内发生的跨学科交互事件数。
    int last_interaction_events <- 0; // 上一次分钟统计时的累计交互次数。
    int last_cross_interaction_events <- 0; // 上一次分钟统计时的累计跨学科交互次数。
    int facility_current_total <- 0; // 当前所有设施内的停留人数。
    int interaction_successes <- 0; // 累计交互成功的配对事件数。
    int interacted_people <- 0; // 至少成功交互一次的独立学生数。
    int cross_interacted_people <- 0; // 至少参与一次跨专业交互的独立学生数。
    int detour_fallback_total <- 0; // 无合法绕行可选时退回最短路的次数。
    int release_1310_checked <- 0; // 已完成13:10强制离开抽样的人数。
    int heat_size <- 80; // 连续热图使用80乘80网格。
    field instant_heatmap <- field(heat_size, heat_size); // 保存当前模型步的道路行走人数。
    field diversity_heatmap <- field(heat_size, heat_size); // 保存当前模型步每格不同专业数。
    file population_file <- csv_file('../includes/population.csv', true); // 读取冻结的人口CSV而非旧人口数据。
    string network_path <- '../includes/single_sites/site_1.json'; // 默认读取无设施基线网络，测试时可切换显式测试网络。
    file network_file <- nil; // 从可调路径读取道路节点与全对路由配置。
    file buildings_file <- json_file('../includes/buildings.geojson'); // 读取经过核验的建筑面图层。
    file roads_file <- json_file('../includes/roads.geojson'); // 读取道路折线图层。
    file portals_file <- json_file('../includes/portals.geojson'); // 读取门户点图层。
    map network_data <- []; // 将网络JSON根对象转成键值表。
    map node_data <- []; // 按稳定节点编号索引原始CAD坐标。
    map route_data <- []; // 按起终点索引路由和备选绕行。
    map building_nodes <- []; // 按建筑编号索引道路接入节点。
    list portal_data <- []; // 保存门户节点与东门标记。
    list facility_data <- []; // 保存正式设施或明确标记的测试设施。
    list road_shapes <- []; // 保存经坐标转换的道路折线供地图显示。
    list building_shapes <- []; // 保存经坐标转换的建筑面供地图显示。
    list portal_shapes <- []; // 保存经坐标转换的门户点供地图显示。
    list<student> student_agents <- []; // 保存学生代理的固定遍历顺序。
    map<string,point> node_points <- []; // 缓存每个道路节点在GAMA显示坐标中的点。
    map<string,int> facility_visits <- []; // 按设施编号累计访问人次。
    map<string,int> facility_unique <- []; // 按设施编号累计独立访客。
    map<string,int> facility_current_people <- []; // 包含正在设施休息及在设施原地等待结束的人，不含路过者。
    map<string,int> facility_interaction_events <- []; // 每处设施累计交互事件数。
    map<string,int> facility_cross_events <- []; // 每处设施累计跨学科交互事件数。
    map<string,int> facility_occupancy <- []; // 按设施编号记录当前休息人数。
    map<string,list<string>> facility_visitor_ids <- []; // 按设施编号保存已到访学生编号。
    map<string,list<string>> diversity_groups <- []; // 记录热图格内本步出现的不同专业。
    map<string,bool> interacted_ids <- []; // 标记已成功交互过的学生。
    map<string,bool> cross_interacted_ids <- []; // 标记参与过跨专业交互的学生。
    map<string,bool> all_unique_visitor_ids <- []; // 以学生编号为键计算全场去重访客人数。
    list<string> major_codes <- ['ENV','CHEM','OCEAN','MARX','PUBLIC_ADMIN']; // 固定五种专业代码及热图顺序。
    list<rgb> major_colors <- [rgb(28,164,94),rgb(239,143,38),rgb(38,124,221),rgb(150,76,198),rgb(220,67,77)]; // 为五种专业指定绿色、橙色、蓝色、紫色、红色。
    list<string> major_labels <- ['环境','化学','海洋','马克思主义','公共管理']; // 专业名称用于图例和结果解释。
    string scenario_label <- ''; // 显示无设施对照或流程测试场景的标签。
    string clock_text function: string(date([2026,1,1,0,0,0]) + now_minute #minute, 'HH:mm'); // 以真实钟点格式显示模拟时间。

    geometry decode_shape(map geo) { // 把GeoJSON点、线、面转换到GAMA从零开始的上下翻转坐标。
        string kind <- string(geo['type']); // 读取GeoJSON几何类型。
        list coords <- list(geo['coordinates']); // 读取嵌套坐标数组。
        if kind='Point' { return {float(coords at 0)-display_min_x, display_max_y-float(coords at 1), 0.0}; } // 转换点并保留米制距离。
        if kind='LineString' { return polyline(decode_points(coords)); } // 转换整条折线并保留道路拐点。
        if kind='Polygon' { geometry poly <- polygon(decode_points(list(coords at 0))); if length(coords)>1 { loop hole_index from: 1 to: length(coords)-1 { poly <- poly-polygon(decode_points(list(coords at hole_index))); } } return poly; } // 转换建筑外环并扣除内部孔洞。
        if kind='MultiPolygon' { geometry combined <- nil; loop part over: coords { geometry one_part <- decode_shape(['type'::'Polygon','coordinates'::part]); combined <- combined=nil ? one_part : combined+one_part; } return combined; } // 合并多面建筑的各个部分。
        assert false label: '地图数据包含未支持的几何类型：'+kind; // 遇到意外的地图格式时明确报错。
        return nil; // 提供不可达分支的返回值以满足函数定义。
    } // 结束地图几何解码函数。

    list<point> decode_points(list coordinates) { // 把一组CAD坐标数组逐点转换到显示坐标。
        list<point> points <- []; // 初始化点列表。
        loop raw_point over: coordinates { list xy <- list(raw_point); add {float(xy at 0)-display_min_x,display_max_y-float(xy at 1),0.0} to: points; } // 平移横坐标并翻转纵坐标。
        return points; // 返回变换后的点列表。
    } // 结束坐标列表解码函数。

    point node_location(string node_id) { // 按道路节点编号取得GAMA世界坐标。
        return node_points[node_id]; // 返回已初始化的节点坐标。
    } // 结束道路节点查询函数。

    string pair_key(string from_node, string to_node) { // 按输入约定生成有向路线缓存键。
        return from_node+'>'+to_node; // 使用大于号分隔起点与终点编号。
    } // 结束路线键函数。

    list route_choice(string from_node, string to_node) { // 选择最短路线或合法绕行路线并返回统一字段。
        string key <- pair_key(from_node,to_node); // 生成该起终点的路线索引。
        assert route_data contains_key key label: '缺少道路路由：'+key; // 缺少路由时停止，禁止瞬移或直线兜底。
        list alternatives <- list(route_data[key]); // 读取该起终点的最短路和备选路径集合。
        map shortest <- map(alternatives at 0); // 按合同规定第一条为最短路径。
        map selected <- shortest; // 默认采用最短路径。
        string selected_kind <- 'shortest'; // 默认路线类型为最短路。
        if length(alternatives)>1 and rnd(0.0,1.0)>=0.8 { // 只有存在备选且随机落入20%时才考虑绕行。
            list legal_detours <- alternatives where (string(map(each)['kind'])='detour' and float(map(each)['length_m'])<=float(shortest['length_m'])*1.25); // 仅保留不超过最短路1.25倍的绕行路线。
            if not empty(legal_detours) { selected <- map(one_of(legal_detours)); selected_kind <- 'detour'; } else { detour_fallback_total <- detour_fallback_total+1; } // 无合法绕行时记录回退并继续走最短路。
        } // 完成路线类型选择。
        return [list(shortest['nodes']),list(selected['nodes']),string(selected['kind']),float(shortest['length_m']),float(selected['length_m'])]; // 返回两条节点序列、类型和两种长度。
    } // 结束路线选择函数。

    int major_index(string code) { // 将专业代码转成固定颜色列表索引。
        return major_codes index_of code; // 返回环境0、化学1、海洋2、马院3、公共管理4。
    } // 结束专业编号函数。

    rgb major_color(string code) { // 查询指定专业的固定地图颜色。
        return major_colors at major_index(code); // 返回专业对应的RGB颜色。
    } // 结束专业颜色函数。

    string csv_record(list cells) { // 逐字段转义CSV，保证中文、逗号和引号均保留在原单元格。
        string row_text <- ''; // 初始化一行文字。
        bool first_cell <- true; // 标记是否为首列。
        loop cell over: cells { string value <- cell=nil ? '' : string(cell); row_text <- row_text+(first_cell ? '' : ',')+'"'+replace(value,'"','""')+'"'; first_cell <- false; } // 引号包围字段并双写字段内的引号。
        return row_text+'\n'; // 返回带换行符的CSV记录。
    } // 结束CSV记录函数。

    action write_event(student person, string event_name, string activity_name, string node_id, int facility_id, string partner_id, bool cross_major) { // 写出状态变化、设施访问和交互事件。
        save csv_record([now_minute,person.student_id,event_name,activity_name,node_id,facility_id,partner_id,cross_major]) to: output_dir+'/events.csv' format: 'text' rewrite: false; // 追加一行结构化事件记录。
    } // 结束事件写出动作。

    action write_decision(student person, string activity_name, string target_node, string reason_text) { // 保存每次活动选择和路线长度。
        save csv_record([now_minute,person.student_id,person.major_code,activity_name,target_node,person.route_kind,person.shortest_length,person.selected_length,reason_text,person.current_node]) to: output_dir+'/decisions.csv' format: 'text' rewrite: false; // 每次新活动计划写出一行决策结果。
    } // 结束决策写出动作。

    action update_heatmaps { // 清空本步热图并按当前步的行走者更新道路热度和学科多样性。
        instant_heatmap <- field(heat_size,heat_size); // 每个模型步都清空瞬时人数热图。
        diversity_heatmap <- field(heat_size,heat_size); // 每步都重新计算当前专业多样性。
        diversity_groups <- []; // 清空当前步每个热图格的专业集合。
        loop person over: student_agents { if person.state='walking' { instant_heatmap[person.location] <- instant_heatmap[person.location]+1; string cell_key <- string(int(person.location.x/(display_width/heat_size)))+':'+string(int(person.location.y/(display_height/heat_size))); list groups <- diversity_groups contains_key cell_key ? list(diversity_groups[cell_key]) : []; if not (groups contains person.major_code) { add person.major_code to: groups; } diversity_groups[cell_key] <- groups; diversity_heatmap[person.location] <- length(groups); } } // 道路瞬时热度只计算正在行走的人，并按实际80乘80网格更新学科多样性。
        loop person over: student_agents { if person.state='facility_rest' { string cell_key <- string(int(person.location.x/(display_width/heat_size)))+':'+string(int(person.location.y/(display_height/heat_size))); list groups <- diversity_groups contains_key cell_key ? list(diversity_groups[cell_key]) : []; if not (groups contains person.major_code) { add person.major_code to: groups; } diversity_groups[cell_key] <- groups; diversity_heatmap[person.location] <- length(groups); } } // 学科多样性热图还计入设施内休息者，但不把建筑内停留者纳入公共空间混合度。
    } // 结束两张瞬时热图更新动作。

    image heat_texture(field source_grid, bool show_diversity) { // 把参考项目的field热场转为GAMA原生连续色带图像。
        matrix<int> pixels <- matrix_with({heat_size,heat_size},int(#black)); // 零热度保持黑色，不伪造有人活动的背景。
        loop cell_key over: diversity_groups.keys { // 只处理有真实行走者或设施停留者的格子，避免全图逐格循环。
            list<string> indexes <- split_with(string(cell_key),':'); // 读取实际热格的横纵编号。
            int column <- int(indexes at 0); int row <- int(indexes at 1); // 同时使用横向和纵向实际格宽。
            float value <- source_grid[column,row]; // 从原始统计热场读取真实数值。
            if value>0 { // 零值格不着热色。
                rgb tone <- #black; // 初始为黑色。
                if show_diversity { tone <- value<1.5 ? rgb(0,80,180) : (value<2.5 ? rgb(0,210,225) : (value<3.5 ? rgb(245,220,60) : (value<4.5 ? rgb(255,125,25) : rgb(235,45,50)))); } // 1至5类专业采用固定蓝、青、黄、橙、红，不随人数自动拉满。
                else { float intensity <- min(1.0,sqrt(value/6.0)); tone <- intensity<0.6 ? rgb(int(255*intensity/0.6),int(165*intensity/0.6),0) : rgb(255,int(165*(1-intensity)/0.4),0); } // 固定0至6人每格的参考强度，超出后保持红色。
                pixels[column,row] <- int(tone); // 写入真实数据对应的颜色。
            } // 结束非零格赋色。
        } // 结束稀疏热格渲染。
        return blurred(with_size(image(pixels),480,288),3); // 原生插值与三次低通滤波让GUI和后台导图都出现连续色带。
    } // 平滑只影响显示，人数、多样性、交互率仍由原始数据计算。

    rgb facility_load_color(int count_people) { // 所有方案共用同一套人数颜色阈值。
        return count_people=0 ? rgb(140,140,140) : (count_people<20 ? rgb(35,170,90) : (count_people<60 ? rgb(245,200,35) : (count_people<150 ? rgb(245,135,35) : rgb(225,55,60)))); // 空置灰色，人数增加依次为绿、黄、橙、红。
    } // 结束设施人数配色查询。

    action update_facility_counts { // 每个两秒模拟步按真实学生状态重算设施瞬时人数。
        facility_current_total <- 0; // 清空当前总人数，不累计历史到访。
        loop raw over: facility_data { map facility <- map(raw); string key <- string(facility['facility_id']); string node <- string(facility['node_id']); int present <- 0; loop person over: student_agents { if (person.state='facility_rest' and person.current_facility_id=int(facility['facility_id'])) or (person.state='destination_wait' and person.current_node=node) { present <- present+1; } } facility_current_people[key] <- present; facility_current_total <- facility_current_total+present; } // 只计实际停留者和原地等待者，不把经过道路的人算进设施。
    } // 结束瞬时人数统计。

    action load_selected_network { // 在初始化阶段按已生效的参数加载路网。
        if network_path='../includes/single_sites/site_1.json' { network_file <- json_file('../includes/single_sites/site_1.json'); } // 使用模型自身目录下的固定相对路径读取点位1。
        else if network_path='../includes/single_sites/site_2.json' { network_file <- json_file('../includes/single_sites/site_2.json'); } // 读取点位2，避免手工拼接路径。
        else if network_path='../includes/single_sites/site_3.json' { network_file <- json_file('../includes/single_sites/site_3.json'); } // 读取点位3。
        else if network_path='../includes/single_sites/site_4.json' { network_file <- json_file('../includes/single_sites/site_4.json'); } // 读取点位4。
        else if network_path='../includes/single_sites/baseline.json' { network_file <- json_file('../includes/single_sites/baseline.json'); } // 读取独立无设施对照。
        else { network_file <- json_file(network_path); } // 保留原生自动验证的显式网络输入能力。
    } // 结束所选路网加载。

    action enter_facility(student person, map facility, string node_id) { // 学生真实到达设施道路节点时记录一次访问并决定休息。
        int facility_id <- int(facility['facility_id']); // 读取设施稳定编号。
        string facility_key <- string(facility_id); // 转换为地图索引字符串。
        list known_visitors <- facility_visitor_ids contains_key facility_key ? list(facility_visitor_ids[facility_key]) : []; // 取得此设施之前所有独立访客。
        bool first_visit <- not (known_visitors contains person.student_id); // 判断此人是否第一次访问当前设施。
        if first_visit { add person.student_id to: known_visitors; facility_visitor_ids[facility_key] <- known_visitors; facility_unique[facility_key] <- (facility_unique contains_key facility_key ? facility_unique[facility_key] : 0)+1; if not (all_unique_visitor_ids contains_key person.student_id) { all_unique_visitor_ids[person.student_id] <- true; unique_visitors_total <- unique_visitors_total+1; } } // 独立设施访客只对该设施计一次，全场去重人数按学生编号计一次。
        facility_visits[facility_key] <- (facility_visits contains_key facility_key ? facility_visits[facility_key] : 0)+1; // 每次实际抵达加一人次。
        facility_occupancy[facility_key] <- (facility_occupancy contains_key facility_key ? facility_occupancy[facility_key] : 0); // 确保当前占用计数已初始化。
        visit_total <- visit_total+1; // 更新全局设施访问人次。
        person.visit_count <- person.visit_count+1; // 更新该学生个人的设施访问人次。
        list<student> partners <- []; // 每名新访客只形成一次有限相遇机会，不假设与设施内所有人都交谈。
        loop other over: student_agents { if other.state='facility_rest' and other.current_facility_id=facility_id and other.student_id!=person.student_id { add other to: partners; } } // 只从此刻同处设施的人中选择伙伴。
        if not empty(partners) { // 至少有另一名停留者才可能交互。
            student other <- one_of(partners); // 为本次到访等概率选择一位现场伙伴。
            interaction_attempts <- interaction_attempts+1; // 每次新到访最多增加一次交互机会。
            bool cross_major <- other.major_code!=person.major_code; // 记录是否来自不同专业。
            do write_event person: person event_name: 'interaction_attempt' activity_name: '设施相遇' node_id: node_id facility_id: facility_id partner_id: other.student_id cross_major: cross_major; // 保存成功和失败都可追溯的分母。
            if rnd(0.0,1.0)<0.6 { // 对这次相遇只抽样一次60%交互概率。
                interaction_successes <- interaction_successes+1; facility_interaction_events[facility_key] <- facility_interaction_events[facility_key]+1; // 累计实际成功的交互事件。
                interacted_ids[person.student_id] <- true; interacted_ids[other.student_id] <- true; // 将双方纳入去重参与人数。
                person.interacted <- true; other.interacted <- true; // 保存逐人交互标记。
                if cross_major { cross_interaction_events <- cross_interaction_events+1; facility_cross_events[facility_key] <- facility_cross_events[facility_key]+1; cross_interacted_ids[person.student_id] <- true; cross_interacted_ids[other.student_id] <- true; person.cross_interacted <- true; other.cross_interacted <- true; } // 单独统计跨专业交互双方。
                do write_event person: person event_name: 'interaction' activity_name: '设施交互' node_id: node_id facility_id: facility_id partner_id: other.student_id cross_major: cross_major; // 记录真实发生的这一次交互。
            } // 同一次停留不会每两秒重复抽样。
        } // 结束有限相遇判断。
        interacted_people <- length(interacted_ids); // 记录至少有一次成功交互的独立人数。
        cross_interacted_people <- length(cross_interacted_ids); // 记录至少参与一次跨专业交互的独立人数。
        person.current_facility_id <- facility_id; // 把当前休息设施保存到学生状态。
        person.state <- 'facility_rest'; // 将学生切换为设施内休息。
        person.stay_until <- now_minute+20.0; // 设施停留20分钟后重新决策。
        person.release_checked_1310 <- now_minute>=790.0; // 13:10之后新进入设施的人不参与已结算的95%强制离开抽样。
        facility_occupancy[facility_key] <- facility_occupancy[facility_key]+1; // 将当前设施占用人数加一。
        do write_event(person,'facility_arrival','设施休息',node_id,facility_id,'',false); // 记录一次实际设施到访事件。
    } // 结束设施访问动作。

    list<string> activity_targets(string activity) { // 列出某活动允许的真实目的地节点。
        list<string> targets <- []; // 初始化目的地列表。
        if activity='a' { add string(building_nodes['1378']) to: targets; } // 吃饭只有学苑食堂。
        else if activity='c' { add string(building_nodes['50001']) to: targets; add string(building_nodes['1344']) to: targets; } // 上课可以选择南北教学楼。
        else if activity='d' { add string(building_nodes['5']) to: targets; } // 自习只有图书馆。
        else if activity='e' { loop raw over: portal_data { add string(map(raw)['node_id']) to: targets; } } // 路过可以选择五个出口。
        else { loop raw over: facility_data { add string(map(raw)['node_id']) to: targets; } } // 休息可以选择本方案内的设施。
        return targets; // 返回完整候选集合。
    } // 结束活动目的地查询。

    list<string> reachable_targets(student person, string activity) { // 只保留按本人步速能在结束前抵达的目的地。
        list<string> eligible <- []; // 初始化可达目的地集合。
        loop target over: activity_targets(activity) { list alternatives <- list(route_data[pair_key(person.current_node,target)]); map shortest <- map(alternatives at 0); if now_minute+float(shortest['length_m'])/person.walking_speed_mps/60.0+0.1<finish_minute { add target to: eligible; } } // 额外预留六秒，容纳两秒离散时步与浮点误差。
        return eligible; // 返回截止时间内可到达的地点。
    } // 结束可达性查询。

    float safe_release(string origin, float original, int cohort, float speed) { // 保留原批次人数，按路程压缩本人的出场窗口。
        float longest <- 0.0; // 计算该起点所有活动可选路径中的保守最长值。
        loop activity over: ['a','b','c','d','e'] { loop target over: activity_targets(activity) { list alternatives <- list(route_data[pair_key(origin,target)]); loop raw over: alternatives { longest <- max(longest,float(map(raw)['length_m'])); } } } // 同时考虑合法绕行，保证首次目的地无需临时加速。
        float begin <- cohort=0 ? 690.0 : (cohort=1 ? 750.0 : 790.0); // 原三批开始时间。
        float end <- cohort=0 ? 750.0 : (cohort=1 ? 790.0 : 810.0); // 原三批结束时间。
        float latest <- min(end,finish_minute-longest/speed/60.0-0.2); // 为本人最长路径再预留十二秒。
        float earliest <- min(begin,latest-1.0); // 路程超过整批时长时允许提前跨入上一时段。
        return earliest+(original-begin)/(end-begin)*(latest-earliest); // 保留均匀分位，避免所有晚出场者挤到同一秒。
    } // 结束截止时间出场安排。

    action hold_at_destination(student person) { // 已到目的地但无法再完成下一趟时，结束继续出行。
        person.state <- 'destination_wait'; // 单列已到达后的等待状态，不伪装成继续吃饭或上课。
        do write_event person: person event_name: 'deadline_hold' activity_name: '已到目的地，等待结束' node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false; // 留下可审查的等待记录。
    } // 结束目的地等待动作。

    action choose_next_activity(student person, string reason_text) { // 按当前时段权重选择下一活动并从实际节点重新规划。
        float activity_time <- reason_text='首次按分层均匀释放规则决策' ? (person.release_cohort=0 ? 700.0 : (person.release_cohort=1 ? 760.0 : 800.0)) : now_minute; // 首次活动保留原批次的概率，提前出发不会改变所属批次。
        list<float> weights <- activity_time<750.0 ? [0.70,0.20,0.0,0.05,0.05] : (activity_time<790.0 ? [0.20,0.45,0.0,0.30,0.05] : [0.0,0.05,0.50,0.0,0.45]); // 使用11:30至12:30、12:30至13:10、13:10至13:30三阶段权重。
        list<string> activities <- ['a','b','c','d','e']; // 固定活动权重的对应顺序。
        loop i from: 0 to: 4 { if not (activities[i]='b' and empty(facility_data)) and empty(reachable_targets(person,activities[i])) { weights[i] <- 0.0; } } // 无法按时抵达的活动本轮不再启动。
        float weight_sum <- sum(weights); // 统计剩余可行活动的原始权重。
        if weight_sum<=0.0 { do hold_at_destination person: person; return; } // 已到目的地后没有可行的新行程则在此等待。
        weights <- weights collect (each/weight_sum); // 在仍可达的活动中归一化原有比例。
        float draw <- rnd(0.0,1.0); // 为此轮活动抽取一次随机数。
        string activity <- draw<weights[0] ? 'a' : (draw<weights[0]+weights[1] ? 'b' : (draw<weights[0]+weights[1]+weights[2] ? 'c' : (draw<weights[0]+weights[1]+weights[2]+weights[3] ? 'd' : 'e'))); // 将抽样结果对应到a至e活动代码。
        person.current_activity <- activity; // 保存选中的活动类别。
        if activity='b' and not empty(facility_data) { list candidates <- facility_data where (reachable_targets(person,'b') contains string(map(each)['node_id'])); map selected_facility <- map(one_of(candidates)); string destination_node <- string(selected_facility['node_id']); person.target_facility_id <- int(selected_facility['facility_id']); do plan_route person: person to_node: destination_node activity_name: activity reason_text: reason_text; } // 有设施时为休息活动等概率选择一个设施。
        else if activity='b' and empty(facility_data) { person.state <- 'baseline_rest'; person.stay_until <- now_minute+20.0; person.route_kind <- 'baseline_local'; person.target_node <- person.current_node; person.shortest_length <- 0.0; person.selected_length <- 0.0; do write_decision person: person activity_name: activity target_node: person.current_node reason_text: reason_text+'；无设施基线原地休息20分钟'; do write_event person: person event_name: 'baseline_rest_start' activity_name: '基线原地休息' node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false; } // 无设施场景将原地休息明确记录为零长度基线决策且不计设施访问。
        else if activity='e' { string destination_node <- one_of(reachable_targets(person,'e')); do plan_route person: person to_node: destination_node activity_name: activity reason_text: reason_text; } // 路过活动的目标是五个门户之一并在抵达后退出。
        else { string destination_node <- one_of(reachable_targets(person,activity)); do plan_route person: person to_node: destination_node activity_name: activity reason_text: reason_text; } // 吃饭去学苑、上课去北/南教学楼、自习去图书馆。
    } // 结束活动选择函数。

    action plan_route(student person, string to_node, string activity_name, string reason_text) { // 从学生当前精确节点规划路线并保存所有路线字段。
        list<string> reachable <- reachable_targets(person,activity_name); // 强制离开设施也必须满足截止时间。
        if not (reachable contains to_node) { if empty(reachable) { do hold_at_destination person: person; return; } to_node <- one_of(reachable); } // 原目标不可达则在同活动可达目标中重新分配。
        list chosen <- route_choice(person.current_node,to_node); // 从预计算全对路线表选择合法路径。
        if now_minute+float(chosen at 4)/person.walking_speed_mps/60.0+0.1>=finish_minute { chosen <- [chosen at 0,chosen at 0,'shortest',chosen at 3,chosen at 3]; } // 绕行来不及时改走原最短路，步速不变。
        person.route_nodes <- list(chosen at 1); // 保存完整的实际道路节点序列。
        person.route_index <- 1; // 从序列第二个节点开始行走，序列第一个节点为当前位置。
        person.route_kind <- string(chosen at 2); // 保存最短或绕行类别。
        person.shortest_length <- float(chosen at 3); // 保存同一起终点的最短路长度。
        person.selected_length <- float(chosen at 4); // 保存实际选中路线长度。
        person.target_node <- to_node; // 保存终点节点。
        person.state <- 'walking'; // 将学生设为行走状态。
        do write_decision person: person activity_name: activity_name target_node: to_node reason_text: reason_text; // 写出本次活动和路线选择依据。
        if length(person.route_nodes)<=1 { person.current_node <- to_node; if activity_name='b' { loop raw_facility over: facility_data { map facility <- map(raw_facility); if int(facility['facility_id'])=person.target_facility_id { do enter_facility person: person facility: facility node_id: to_node; } } } else { do begin_target_stay person: person; } } // 起终点相同的零长度路线立即处理到达，避免访问不存在的下一节点。
    } // 结束实际路线规划动作。

    action begin_target_stay(student person) { // 学生抵达活动目标后按活动类别停留30分钟或退出。
        if person.current_activity='e' { person.state <- 'exited'; do write_event person: person event_name: 'exit' activity_name: '路过退出' node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false; } // 到达门户后离开模拟区域。
        else { person.state <- person.current_activity='a' ? 'eating' : (person.current_activity='c' ? 'in_class' : 'studying'); person.stay_until <- now_minute+30.0; do write_event person: person event_name: 'building_arrival' activity_name: person.current_activity node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false; } // 在食堂、教学楼或图书馆停留30分钟。
    } // 结束活动目标抵达处理。

    action move_student(student person) { // 每个模型步最多前进个人速度乘两秒并允许连续越过短道路边。
        float remaining <- person.walking_speed_mps*step_seconds; // 计算本步最多可走的真实米数。
        if export_trace and person.student_order<trace_limit { save csv_record([now_minute,person.student_id,'walking','before',person.location.x+display_min_x,display_max_y-person.location.y,person.walking_speed_mps]) to: output_dir+'/motion.csv' format: 'text' rewrite: false; } // 可选记录本步移动前坐标并还原为CAD坐标。
        int guard <- 0; // 设置短边界保护，避免异常路线造成无限循环。
        loop while: (remaining>0.000001 and person.state='walking' and guard<40 and person.route_index<length(person.route_nodes)) { guard <- guard+1; string next_node <- string(person.route_nodes at person.route_index); point next_point <- node_location(next_node); float gap <- person.location distance_to next_point; if gap<=remaining+0.000001 { person.location <- next_point; person.current_node <- next_node; remaining <- max(0.0,remaining-gap); person.route_index <- person.route_index+1; if not empty(facility_data) and now_minute<790.0 and person.current_activity!='b' { loop facility_raw over: facility_data { map facility <- map(facility_raw); if string(facility['node_id'])=person.current_node and rnd(0.0,1.0)<0.3 { do enter_facility person: person facility: facility node_id: person.current_node; } } } if person.state='walking' and person.current_node=person.target_node { if person.current_activity='b' { loop target_raw over: facility_data { map target_facility <- map(target_raw); if int(target_facility['facility_id'])=person.target_facility_id { do enter_facility person: person facility: target_facility node_id: person.current_node; } } } else { do begin_target_stay person: person; } } else if person.state='walking' and person.route_index>=length(person.route_nodes) { do begin_target_stay person: person; } } else { float ratio <- remaining/gap; person.location <- {person.location.x+(next_point.x-person.location.x)*ratio,person.location.y+(next_point.y-person.location.y)*ratio,0.0}; remaining <- 0.0; } } // 精确抵达节点并以剩余步长继续短路段，不使用瞬移。
        if export_trace and person.student_order<trace_limit { save csv_record([now_minute,person.student_id,person.state,'after',person.location.x+display_min_x,display_max_y-person.location.y,person.walking_speed_mps]) to: output_dir+'/motion.csv' format: 'text' rewrite: false; } // 可选记录本步移动后坐标。
    } // 结束道路移动动作。

    action write_minute_statistics { // 统计所有互斥状态并写出指定CSV列。
        minute_interaction_events <- interaction_successes-last_interaction_events; minute_cross_interaction_events <- cross_interaction_events-last_cross_interaction_events; last_interaction_events <- interaction_successes; last_cross_interaction_events <- cross_interaction_events; // 用真实事件计数差得到本分钟新增次数。
        loop raw over: facility_data { map facility <- map(raw); string key <- string(facility['facility_id']); save csv_record([now_minute,key,facility_current_people[key],facility_occupancy[key],facility_current_people[key]-facility_occupancy[key],facility_interaction_events[key],facility_cross_events[key]]) to: output_dir+'/facility_statistics.csv' format: 'text' rewrite: false; } // 单独导出每处设施的瞬时人数及累计交互次数，便于逐事件复核。
        n_destination_wait <- 0; n_not_released <- 0; n_walking <- 0; n_eating <- 0; n_studying <- 0; n_class <- 0; n_facility_rest <- 0; n_baseline_rest <- 0; n_exited <- 0; // 初始化八种互斥状态人数。
        loop person over: student_agents { if person.state='not_released' { n_not_released <- n_not_released+1; } else if person.state='walking' { n_walking <- n_walking+1; } else if person.state='eating' { n_eating <- n_eating+1; } else if person.state='studying' { n_studying <- n_studying+1; } else if person.state='in_class' { n_class <- n_class+1; } else if person.state='facility_rest' { n_facility_rest <- n_facility_rest+1; } else if person.state='baseline_rest' { n_baseline_rest <- n_baseline_rest+1; } else if person.state='destination_wait' { n_destination_wait <- n_destination_wait+1; } else if person.state='exited' { n_exited <- n_exited+1; } } // 逐人计数确保八种状态合计等于1474。
        save csv_record([int(now_minute),total_population,n_not_released,n_walking,n_eating,n_studying,n_class,n_facility_rest,n_baseline_rest,n_exited,released_total,visit_total,unique_visitors_total,interaction_attempts,interaction_successes,interacted_people,cross_interacted_people,n_destination_wait,facility_current_total,cross_interaction_events,minute_interaction_events,minute_cross_interaction_events]) to: output_dir+'/statistics.csv' format: 'text' rewrite: false; // 按用户固定列顺序写出每分钟统计数据。
    } // 结束分钟统计输出动作。

    action write_final_outputs { // 写出逐人最终状态和累计访问、交互标记摘要。
        assert empty(student_agents where (each.state='walking' or each.state='not_released')) label: '13:30仍有人行走或未出场，拒绝宣称全员到达'; // 最终状态必须真实完成而不是仅停止时钟。
        loop person over: student_agents { save csv_record([now_minute,person.student_id,person.major_code,person.state,person.visit_count,person.interacted,person.cross_interacted]) to: output_dir+'/summary.csv' format: 'text' rewrite: false; } // 每位学生写一行最终状态及个人累计计数。
        save 'NOON_MODEL_FINISHED: students=1474 visits='+string(visit_total)+' interactions='+string(interaction_successes)+'\n' to: output_dir+'/model.log' format: 'text' rewrite: false; // 写入可检索的完成标记。
    } // 结束最终结果写出动作。

    init { // 读取网络、底图和人口并初始化实验结果表。
        seed <- random_seed; // 固定GAMA内部随机数种子。
        do load_selected_network; network_data <- map(network_file.contents); node_data <- map(network_data['nodes']); route_data <- map(network_data['routes']); building_nodes <- map(network_data['building_nodes']); portal_data <- list(network_data['portals']); facility_data <- list(network_data['facilities']); scenario_label <- string(network_data['scenario_label']); // 按实验参数重新载入基线或测试路网配置。
        list raw_nodes <- node_data.keys as list; // 读取全部道路节点编号。
        loop node_id over: raw_nodes { list xy <- list(node_data[string(node_id)]); node_points[string(node_id)] <- {float(xy at 0)-display_min_x,display_max_y-float(xy at 1),0.0}; } // 建立道路编号到显示坐标的索引。
        map building_doc <- map(buildings_file.contents); loop raw_feature over: list(building_doc['features']) { map feature <- map(raw_feature); map properties <- map(feature['properties']); geometry building_shape <- decode_shape(map(feature['geometry'])); add building_shape to: building_shapes; create building_layer number: 1 { shape <- building_shape; building_name <- string(properties['bld_name']); } } // 读取建筑轮廓、保留楼名并创建灰色建筑面代理。
        map road_doc <- map(roads_file.contents); loop raw_feature over: list(road_doc['features']) { map feature <- map(raw_feature); add decode_shape(map(feature['geometry'])) to: road_shapes; } loop road_shape over: road_shapes { create road_layer number: 1 { shape <- road_shape; } } // 读取道路折线并创建深蓝道路代理。
        map portal_doc <- map(portals_file.contents); loop raw_feature over: list(portal_doc['features']) { map feature <- map(raw_feature); map properties <- map(feature['properties']); geometry portal_point <- decode_shape(map(feature['geometry'])); add portal_point to: portal_shapes; create portal_layer number: 1 { shape <- portal_point; portal_id <- int(properties['portal_id']); portal_name <- string(properties['name']); } } // 读取门户坐标并创建带名称和编号的门户代理。
        matrix records <- population_file.contents; // 取得人口CSV表格数据矩阵。
        assert length(records column_at 0)=total_population label: '冻结人口CSV人数与1474不一致'; // 检查种群规模准确。
        loop row_index from: 0 to: total_population-1 { int row <- row_index; string sid <- string(records[0,row]); string major <- string(records[1,row]); string origin_kind <- string(records[4,row]); string origin_building <- string(records[5,row]); string origin_node <- origin_kind='building' ? string(building_nodes[origin_building]) : ''; if origin_kind='east_portal' { list east_portals <- portal_data where (bool(map(each)['is_east'])); map east_portal <- map(one_of(east_portals)); origin_node <- string(east_portal['node_id']); } assert node_points contains_key origin_node label: '人口起点缺少道路节点：'+sid; create student number: 1 { student_id <- sid; major_code <- major; state <- 'not_released'; release_minute <- float(records[7,row]); walking_speed_mps <- float(records[9,row]); release_cohort <- int(records[8,row]); release_minute <- world.network_data contains_key 'release_schedule' ? float(map(world.network_data['release_schedule'])[sid]) : world.safe_release(origin_node,release_minute,release_cohort,walking_speed_mps); current_node <- origin_node; target_node <- origin_node; location <- world.node_location(origin_node); student_order <- row_index; visit_count <- 0; interacted <- false; cross_interacted <- false; current_facility_id <- -1; target_facility_id <- -1; current_activity <- ''; route_nodes <- []; route_index <- 0; route_kind <- 'none'; shortest_length <- 0.0; selected_length <- 0.0; stay_until <- -1.0; release_checked_1310 <- false; } } // 每行CSV构建一个未出场学生并准确绑定建筑或东门起点。
        loop facility_raw over: facility_data { map facility <- map(facility_raw); facility_visits[string(facility['facility_id'])] <- 0; facility_unique[string(facility['facility_id'])] <- 0; facility_occupancy[string(facility['facility_id'])] <- 0; facility_current_people[string(facility['facility_id'])] <- 0; facility_interaction_events[string(facility['facility_id'])] <- 0; facility_cross_events[string(facility['facility_id'])] <- 0; facility_visitor_ids[string(facility['facility_id'])] <- []; create facility_marker number: 1 { facility_id <- int(facility['facility_id']); location <- world.node_location(string(facility['node_id'])); } } // 初始化每处设施计数并创建地图访问标记。
        student_agents <- student as list; // 缓存代理列表以便每步稳定顺序遍历。
        save 'minute,total,not_released,walking,eating,studying,in_class,facility_rest,baseline_rest,exited,released,visits,unique_visitors,interaction_attempts,interaction_successes,interacted_people,cross_interacted_people,destination_wait,facility_current_people,cross_interaction_events,minute_interaction_events,minute_cross_interaction_events\n' to: output_dir+'/statistics.csv' format: 'text' rewrite: true; // 创建统计CSV及固定列名。
        save 'minute,facility_id,current_people,active_resting,waiting,interaction_events,cross_interaction_events\n' to: output_dir+'/facility_statistics.csv' format: 'text' rewrite: true; // 创建设施瞬时人数与事件次数表。
        save 'minute,student_id,major,activity,target_node,route_kind,shortest_length,selected_length,reason,from_node\n' to: output_dir+'/decisions.csv' format: 'text' rewrite: true; // 创建决策CSV及固定列名。
        save 'minute,student_id,event,activity,node_id,facility_id,partner_id,cross_major\n' to: output_dir+'/events.csv' format: 'text' rewrite: true; // 创建事件CSV及固定列名。
        save 'minute,student_id,major,state,visits,interacted,cross_interacted\n' to: output_dir+'/summary.csv' format: 'text' rewrite: true; // 创建逐人摘要CSV及固定列名。
        if export_trace { save 'minute,student_id,state,phase,cad_x,cad_y,speed_mps\n' to: output_dir+'/motion.csv' format: 'text' rewrite: true; } // 仅开启时创建可还原的逐步轨迹CSV。
        save 'NOON_MODEL_CHECK: students=1474 facilities='+string(length(facility_data))+' scenario='+scenario_label+'\n' to: output_dir+'/model.log' format: 'text' rewrite: true; // 写入模型开始校验标记和场景说明。
        write 'NOON_MODEL_CHECK: students=1474 facilities='+string(length(facility_data)); // 在GAMA控制台打印同一校验标记。
        initialized <- true; // 初始化全部结束后允许主协调循环运行。
    } // 结束模型初始化。

    reflex coordinate_noon when: initialized and not finished { // 每步按固定顺序释放、移动、停留和更新热图。
        now_minute <- min(finish_minute,now_minute+step_minutes); // 将模拟钟推进两秒并限制到13:30。
        loop person over: student_agents { if person.state='not_released' and now_minute+0.00001>=person.release_minute { person.state <- 'walking'; released_total <- released_total+1; do choose_next_activity person: person reason_text: '首次按分层均匀释放规则决策'; do write_event person: person event_name: 'release' activity_name: person.current_activity node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false; } } // 按冻结的逐人释放时刻开始活动并容忍两秒网格浮点误差。
        loop person over: student_agents { if person.state='walking' { do move_student person: person; } else if person.state='facility_rest' and now_minute>=790.0 and not person.release_checked_1310 { person.release_checked_1310 <- true; release_1310_checked <- release_1310_checked+1; if rnd(0.0,1.0)<0.95 { string fkey <- string(person.current_facility_id); facility_occupancy[fkey] <- max(0,facility_occupancy[fkey]-1); person.current_facility_id <- -1; person.current_activity <- rnd(0.0,1.0)<(50.0/95.0) ? 'c' : 'e'; person.state <- 'walking'; if person.current_activity='e' { map portal <- map(one_of(portal_data)); do plan_route person: person to_node: string(portal['node_id']) activity_name: 'e' reason_text: '13:10设施离开95%分支，按50:45归一化'; } else { string target <- string(building_nodes[string(rnd(0.0,1.0)<0.5 ? 50001 : 1344)]); do plan_route person: person to_node: target activity_name: 'c' reason_text: '13:10设施离开95%分支，按50:45归一化'; } do write_event person: person event_name: 'facility_forced_leave' activity_name: person.current_activity node_id: person.current_node facility_id: int(fkey) partner_id: '' cross_major: false; } else { do write_event person: person event_name: 'facility_retained' activity_name: '保留原休息时长' node_id: person.current_node facility_id: person.current_facility_id partner_id: '' cross_major: false; } } else if (person.state='eating' or person.state='studying' or person.state='in_class') and now_minute>=person.stay_until { person.state <- 'walking'; do choose_next_activity person: person reason_text: '建筑停留30分钟结束后按当前时段重新决策'; } else if person.state='baseline_rest' and now_minute>=person.stay_until { person.state <- 'walking'; do write_event person: person event_name: 'baseline_rest_end' activity_name: '基线原地休息结束' node_id: person.current_node facility_id: -1 partner_id: '' cross_major: false; do choose_next_activity person: person reason_text: '无设施基线原地休息20分钟结束后重新决策'; } else if person.state='facility_rest' and now_minute>=person.stay_until { string fkey <- string(person.current_facility_id); facility_occupancy[fkey] <- max(0,facility_occupancy[fkey]-1); int former_facility <- person.current_facility_id; person.current_facility_id <- -1; person.state <- 'walking'; do write_event person: person event_name: 'facility_rest_end' activity_name: '设施休息结束' node_id: person.current_node facility_id: former_facility partner_id: '' cross_major: false; do choose_next_activity person: person reason_text: '设施停留20分钟结束后按当前时段重新决策'; } } // 更新每名学生状态；13:10前已在设施者只抽样一次且记录强制离开或保留结果。
        do update_facility_counts; // 在移动和停留全部更新后统计设施实际在场人数。
        do update_heatmaps; // 更新当前步的道路行走热度和学科多样性热力。
        int rounded_minute <- int(now_minute); if rounded_minute>last_stat_minute { last_stat_minute <- rounded_minute; do write_minute_statistics; } // 进入新的整分钟时写出一行统计。
        if now_minute>=finish_minute and not finished { do write_final_outputs; initialized <- false; finished <- true; do pause; } // 13:30写最终摘要后关闭协调循环并暂停模型。
    } // 结束每步主协调流程。
} // 结束全局模型规则。

species student { // 学生只保存状态，由全局协调循环按稳定顺序更新。
    string student_id <- ''; // 保存匿名学生编号。
    string major_code <- ''; // 保存专业代码。
    string state <- 'not_released'; // 当前互斥活动状态。
    string current_activity <- ''; // 当前活动代码a至e。
    string current_node <- ''; // 学生当前精确抵达的路网节点。
    string target_node <- ''; // 当前目标节点。
    list<string> route_nodes <- []; // 选中的路线节点序列。
    int route_index <- 0; // 下一个要抵达的节点序号。
    string route_kind <- 'none'; // 本次路线为最短路、绕行或尚未规划。
    float shortest_length <- 0.0; // 起终点间最短道路长度。
    float selected_length <- 0.0; // 实际选中路线的道路长度。
    int release_cohort <- 0; // 原人口表中的三批标签，人数保持884、295、295。
    float release_minute <- 0.0; // 冻结人口表提供的出场时刻。
    float walking_speed_mps <- 1.0; // 冻结人口表提供的个人步行速度。
    float stay_until <- -1.0; // 当前停留结束时刻。
    int current_facility_id <- -1; // 当前设施休息点编号，无设施为负一。
    int target_facility_id <- -1; // 当前目标设施编号，无设施为负一。
    int student_order <- -1; // 学生在输入CSV中的稳定行号。
    int visit_count <- 0; // 个人设施访问次数。
    bool interacted <- false; // 是否至少成功参与一次交互。
    bool cross_interacted <- false; // 是否至少参与一次跨专业交互。
    bool release_checked_1310 <- false; // 是否已处理一次13:10的设施离开抽样。
    aspect major_marker { if state!='not_released' and state!='exited' { draw circle(4) color: world.major_color(major_code) border: #black; } } // 仅显示已出场且尚未离开的学生，并按专业绘制4米点。
} // 结束学生代理定义。

species building_layer { // 建筑底图使用预转换的建筑几何。
    string building_name <- ''; // 保留建筑图层原始楼名。
    aspect base { draw shape color: rgb(190,190,190) border: rgb(95,95,95); draw building_name at: location color: #black font: font('SansSerif',9); } // 建筑采用灰色面、深灰轮廓和黑色楼名。
    aspect heat { draw shape color: rgb(35,43,54) border: rgb(70,82,95); draw building_name at: location color: rgb(175,190,205) font: font('Microsoft YaHei',8) anchor: #center; } // 热图建筑采用低亮度底色，避免遮盖连续热色。
} // 结束建筑图层代理定义。

species portal_layer { // 校园门户代理用于显示东门与其他校门编号。
    int portal_id <- -1; // 保存门户编号。
    string portal_name <- ''; // 保存门户名称。
    aspect base { draw circle(5) color: #yellow border: #black; draw portal_name at: location color: #black font: font('SansSerif',9); } // 用黄色点和中文名称标识门户。
} // 结束门户代理定义。

species road_layer { // 道路底图使用预转换的道路折线。
    aspect base { draw shape color: rgb(35,70,105) width: 2.0; } // 道路以深蓝色线条显示。
    aspect heat { draw shape color: rgb(45,62,75) width: 0.7; } // 暗色道路作定位底线，不抢热色。
} // 结束道路图层代理定义。

species facility_marker { // 设施位置用醒目圆圈显示访问程度。
    int facility_id <- -1; // 保存网络数据中的设施编号。
    aspect locator { int present <- world.facility_current_people[string(facility_id)]; draw circle(4.5) color: #white border: #black; draw circle(2.8) color: world.facility_load_color(present) border: #black; draw '现'+string(present)+'人' at: location+{8,-8} color: #black font: font('Microsoft YaHei',9); } // 浅色地图上的设施点按真实当前人数变色，并显示人数。
    aspect locator_dark { int present <- world.facility_current_people[string(facility_id)]; draw circle(4.5) color: #white border: #black; draw circle(2.8) color: world.facility_load_color(present) border: #black; draw '现'+string(present)+'人' at: location+{8,-8} color: #white font: font('Microsoft YaHei',9); } // 深色热力图使用白色人数文字，保留同样的配色阈值。
} // 结束设施图标代理定义。

experiment NoonScope type: gui { // 创建包含五个用户指定视图的图形实验。
    float minimum_cycle_duration <- 0.1; // GUI每个模型步最短播放时间，确保移动过程可见。
    parameter '每步最短播放秒' var: minimum_cycle_duration min: 0.0 max: 1.0; // 可在快速验证时设为零。
    parameter '设施点位（site_1至site_4，baseline为无设施）' var: network_path among: ['../includes/single_sites/site_1.json','../includes/single_sites/site_2.json','../includes/single_sites/site_3.json','../includes/single_sites/site_4.json','../includes/single_sites/baseline.json']; // 直接选择文件名中的点位编号，无需手填路径。
    parameter '随机种子' var: random_seed min: 1 max: 999999; // 可调整活动与路线随机选择种子。
    parameter '导出逐步轨迹' var: export_trace; // 可选打开逐步CAD坐标移动记录。
    parameter '轨迹学生上限' var: trace_limit min: 0 max: 1474; // 设置逐步轨迹人数上限。
    parameter '统计输出目录' var: output_dir; // 可调整结果CSV的保存位置。
    output { // 定义五个精确命名的地图和统计窗口。
        layout #stack tabs: true editors: false navigator: false parameters: true consoles: true; // 五个视图用标签切换，避免挤成小窗口。
        display '专业人员移动' type: java2D refresh: (initialized and not finished) { species building_layer aspect: base; species road_layer aspect: base; species portal_layer aspect: base; species student aspect: major_marker; graphics Legend { draw '环境' at: {10,20} color: rgb(28,164,94); draw '化学' at: {10,38} color: rgb(239,143,38); draw '海洋' at: {10,56} color: rgb(38,124,221); draw '马克思主义' at: {10,74} color: rgb(150,76,198); draw '公共管理' at: {10,92} color: rgb(220,67,77); draw scenario_label+'  '+clock_text at: {10,112} color: #black; } species facility_marker aspect: locator; graphics FacilityLoadLegend { draw '设施人数：0灰 / 1—19绿 / 20—59黄 / 60—149橙 / 150+红' at: {10,130} color: #black font: font('Microsoft YaHei',9); } } // 按专业颜色显示移动点、楼名和门户并标注场景与模拟时钟。
        display '道路瞬时热力' type: java2D refresh: (initialized and not finished) background: #black { graphics DensityTexture { draw heat_texture(instant_heatmap,false) at: {display_width/2,display_height/2} size: {display_width,display_height}; } species road_layer aspect: heat; species building_layer aspect: heat; graphics Clock { draw clock_text+'  '+scenario_label at: {10,20} color: #white; draw '瞬时行走密度：黑→橙→红；固定强度参考上限6人/格，显示平滑' at: {10,37} color: #white; } species facility_marker aspect: locator_dark; graphics FacilityLoadLegend { draw '设施人数：0灰 / 1—19绿 / 20—59黄 / 60—149橙 / 150+红' at: {10,54} color: #white font: font('Microsoft YaHei',9); } } // 用参考field数据的原生插值色带显示瞬时道路人流，保留可辨识底图。
        display '设施累计到访' type: java2D refresh: (initialized and not finished) { species building_layer aspect: base; species road_layer aspect: base; graphics FacilityVisits { loop marker over: facility_marker { draw string(facility_unique[string(marker.facility_id)])+'人 / '+string(facility_visits[string(marker.facility_id)])+'人次' at: marker.location+{8,12} color: #black; } } graphics Clock { draw clock_text+'  '+scenario_label+'；累计独立人数 / 到访人次' at: {10,20} color: #black; } species facility_marker aspect: locator; graphics FacilityLoadLegend { draw '设施人数：0灰 / 1—19绿 / 20—59黄 / 60—149橙 / 150+红' at: {10,37} color: #black font: font('Microsoft YaHei',9); } } // 固定小点标注设施位置，旁边显示独立人数和到访人次。
        display '活动状态曲线' type: java2D refresh: (initialized and not finished) { chart '人数状态变化' type: series x_serie_labels: clock_text { data '未出场' value: n_not_released color: #gray; data '行走' value: n_walking color: #blue; data '吃饭' value: n_eating color: #orange; data '休息' value: n_facility_rest+n_baseline_rest color: #green; data '上课' value: n_class color: #purple; data '自习' value: n_studying color: #cyan; data '到达后等待' value: n_destination_wait color: rgb(130,110,70); data '已离开' value: n_exited color: #red; } graphics FacilityIndicator { if not empty(facility_data) { draw circle(4) at: {12,8} color: facility_load_color(facility_current_total) border: #black; } draw scenario_label+'；当前设施人数：'+string(facility_current_total)+'人' at: {21,8} color: #black font: font('Microsoft YaHei',9); } } // 显示未出场、移动、活动和离开人数的时间曲线。
        display '学科多样性热力' type: java2D refresh: (initialized and not finished) background: #black { graphics DiversityTexture { draw heat_texture(diversity_heatmap,true) at: {display_width/2,display_height/2} size: {display_width,display_height}; } species road_layer aspect: heat; species building_layer aspect: heat; graphics Clock { draw clock_text+'  '+scenario_label at: {10,20} color: #white; draw '同格专业种类：1蓝 / 2青 / 3黄 / 4橙 / 5红；含设施停留者' at: {10,37} color: #white; } species facility_marker aspect: locator_dark; graphics FacilityLoadLegend { draw '设施人数：0灰 / 1—19绿 / 20—59黄 / 60—149橙 / 150+红' at: {10,54} color: #white font: font('Microsoft YaHei',9); } } // 多样性用固定五档原始格统计，平滑显示不改变计数。
        display '设施交互事件曲线' type: java2D refresh: (initialized and not finished) { chart '设施内每分钟交互次数' type: series x_serie_labels: clock_text { data '全部交互（次/分钟）' value: minute_interaction_events color: rgb(35,120,220); data '跨学科交互（次/分钟）' value: minute_cross_interaction_events color: rgb(180,65,190); } graphics InteractionTotals { if not empty(facility_data) { draw circle(4) at: {12,8} color: facility_load_color(facility_current_total) border: #black; } draw scenario_label+'；累计交互 '+string(interaction_successes)+' 次；累计跨学科 '+string(cross_interaction_events)+' 次' at: {21,8} color: #black font: font('Microsoft YaHei',9); } } // 两条曲线统计真实事件次数，顶部显示累计次数，跨学科事件属于全部交互的子集。
    } // 结束六个视图定义。
} // 结束图形实验定义。

experiment NoonScopeVerify type: gui { // 后台完整行为验证使用同一套模型规则，不重复绘制五图。
    float minimum_cycle_duration <- 0.0; // 自动验证不增加人工播放延时。
    parameter '每步最短播放秒' var: minimum_cycle_duration min: 0.0 max: 1.0; // 保持原生XML参数一致。
    parameter '网络配置路径' var: network_path; // 正式无设施与测试夹具分别指定。
    parameter '随机种子' var: random_seed; // 核验同种子复现和不同种子随机性。
    parameter '导出逐步轨迹' var: export_trace; // 为独立空间检查导出真实运动。
    parameter '轨迹学生上限' var: trace_limit; // 仍然模拟全部1474人，只抽样记录运动。
    parameter '统计输出目录' var: output_dir; // 每个测试结果保存到独立目录。
    output { monitor '已出场人数' value: released_total; monitor '交互参与人数' value: interacted_people; } // 检查同一状态机的全局结果。
} // 用户正式操作入口仍为上面的NoonScope五图实验。
