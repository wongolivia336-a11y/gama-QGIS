# 数据字典与采集方案

## 课程任务记录

建议字段：`term,new_course_id,course_code,course_name,campus,college,total_hours,course_type,assessment,teacher,schedule_text,room,week_pattern,major,capacity,enrollment`。

清洗规则：保留原始 `schedule_text`；解析星期、节次、周次和教室为派生字段；保留校区字段；去除教师工号等不必要个人标识；禁止把 `major`、`capacity`、`enrollment` 推断成个人选课或出勤。

## 空间对象

`building_id,name,type,campus,geometry,discipline_relevance,source,confidence`。

当前对象清单只记录官方资料中出现的名称和功能，不填未经配准的坐标。坐标来源优先级：官方 GIS/配准 DWG > 官方地图控制点 > OSM > 人工估计。人工估计必须标注 `estimated`。

## 获取顺序

1. 课程网站公开导出或授权接口；每次请求低频、保存时间和字段。
2. 官方校园地图和楼宇页面。
3. OSM/OSMnx 补充道路网络；留存下载日期和查询语句。
4. 现场观察、访谈或问卷补足开放时间、遮阴、热舒适和拥挤数据。
