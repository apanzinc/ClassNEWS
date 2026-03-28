import requests
import json
import random
import re
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

def fetch_news_page(page=1, page_size=50, date=None):
    """从央视API获取单页新闻数据"""
    url = "https://api.cntv.cn/NewVideo/getVideoListByColumn"
    
    # 获取当前日期
    if date is None:
        date = datetime.now().strftime("%Y%m%d")
    
    params = {
        "id": "TOPC1451558496100826",  # 朝闻天下栏目ID
        "n": str(page_size),  # 每页数量
        "sort": "desc",
        "p": str(page),
        "bd": date,  # 指定日期
        "mode": "2",
        "serviceId": "tvcctv"
    }
    
    try:
        response = requests.get(url, params=params, timeout=15)
        response.raise_for_status()
        
        # 处理JSONP格式 (cb({...}))
        text = response.text
        if text.startswith("cb(") and text.endswith(")"):
            text = text[3:-1]  # 去掉 cb( 和 )
        
        data = json.loads(text)
        
        # 提取新闻列表
        news_list = []
        full_version = None  # 完整版节目
        
        if "data" in data and "list" in data["data"]:
            for idx, item in enumerate(data["data"]["list"]):
                title = item.get("title", "").replace("[朝闻天下]", "").strip()
                brief = item.get("brief", "")
                length = item.get("length", "")
                
                # 检测是否是完整版节目
                # 特征1：brief包含"本期节目主要内容"或"本期主要内容"
                # 特征2：标题格式为"《节目名》 YYYYMMDD HH:MM"
                # 特征3：时长较长（通常超过30分钟）
                has_main_content = "本期节目主要内容" in brief or "本期主要内容" in brief
                is_program_title = bool(re.match(r'《[^》]+》\s*\d{8}\s+\d{2}:\d{2}', title))
                
                # 解析时长（格式：HH:MM:SS）
                is_long_duration = False
                if length:
                    try:
                        parts = length.split(':')
                        if len(parts) == 3:
                            hours = int(parts[0])
                            if hours >= 0.5:  # 超过30分钟
                                is_long_duration = True
                    except:
                        pass
                
                # 判断是否为完整版：包含主要内容描述，或者是节目标题格式
                is_full_version = has_main_content or (is_program_title and is_long_duration)
                
                # 调试：打印前3条新闻的检测信息
                if idx < 3:
                    print(f"[{idx}] 标题: {title[:40]}...")
                    print(f"    时长: {length}, 是否节目标题: {is_program_title}, 是否长时长: {is_long_duration}")
                    print(f"    是否完整版: {is_full_version}")
                
                # 如果是完整版，保存它
                if is_full_version and not full_version:
                    video_id = item.get("guid", "")
                    full_version = {
                        "title": title,
                        "summary": "完整版节目",
                        "image": item.get("image", ""),
                        "url": url,
                        "time": item.get("time", ""),
                        "videoId": video_id,
                        "isFullVersion": True,  # 标记为完整版
                        "length": length
                    }
                    continue
                
                # 跳过其他"主要内容"综合新闻
                if "本期节目主要内容" in brief or "本期主要内容" in brief:
                    continue
                if "；" in brief and brief.count("。") > 3:
                    # 包含多个句号和分号，可能是综合新闻
                    continue
                
                # 获取视频ID (guid字段是正确的视频ID)
                video_id = item.get("guid", "")

                news_item = {
                    "title": title,
                    "summary": brief,
                    "image": item.get("image", ""),
                    "url": url,
                    "time": item.get("time", ""),
                    "videoId": video_id,  # 视频ID，用于解析播放
                    "isFullVersion": False
                }
                news_list.append(news_item)
        
        # 如果有完整版，插入到列表开头
        if full_version:
            news_list.insert(0, full_version)
            print(f"已添加完整版节目: {full_version['title']} ({full_version['length']})")
        
        # 获取总数量
        total = data.get("data", {}).get("total", 0)
        
        # 打印前几条新闻的标题，用于调试顺序
        if news_list:
            print("新闻列表前5条:")
            for i, news in enumerate(news_list[:5]):
                print(f"  [{i}] {news['title'][:30]}...")
        
        return news_list, total
    except Exception as e:
        print(f"获取第 {page} 页新闻失败: {e}")
        return [], 0


def filter_news_by_time_slot(news_list):
    """
    根据时间段筛选新闻，只保留一个时间段的内容
    优先级：8点完整版 > 6点完整版 > 6点片段
    """
    if not news_list:
        return []
    
    # 分离完整版和普通新闻
    full_versions = []
    regular_news = []
    
    for news in news_list:
        if news.get("isFullVersion"):
            full_versions.append(news)
        else:
            regular_news.append(news)
    
    # 解析完整版的时间（从标题中提取 HH:MM）
    def extract_time(full_version):
        title = full_version.get("title", "")
        match = re.search(r'(\d{2}):(\d{2})', title)
        if match:
            return int(match.group(1)) * 60 + int(match.group(2))  # 转换为分钟
        return 0
    
    # 按时间排序完整版（8点 > 6点）
    full_versions.sort(key=extract_time, reverse=True)
    
    # 选择要使用的完整版
    selected_full_version = None
    if full_versions:
        # 优先选择8点的（时间更大）
        selected_full_version = full_versions[0]
        print(f"选择完整版: {selected_full_version['title']}")
    
    # 根据完整版筛选对应时间段的新闻
    if selected_full_version:
        # 提取完整版的时间标识（如 "08:00" 或 "06:00"）
        title = selected_full_version.get("title", "")
        time_match = re.search(r'(\d{2}):\d{2}', title)
        target_hour = time_match.group(1) if time_match else None
        
        if target_hour:
            # 只保留同一时间段的新闻
            filtered_news = []
            for news in regular_news:
                news_title = news.get("title", "")
                # 检查新闻标题是否包含相同的时间段标识
                if target_hour in news_title or f"{target_hour}:" in news_title:
                    filtered_news.append(news)
            
            # 如果没有找到匹配的新闻，使用所有普通新闻
            if not filtered_news:
                filtered_news = regular_news
            
            # 组装最终结果：完整版 + 对应时间段的新闻
            result = [selected_full_version] + filtered_news
            print(f"筛选后新闻数: {len(result)} (完整版1条 + 普通新闻{len(filtered_news)}条)")
            return result
        else:
            # 无法提取时间，返回完整版 + 所有普通新闻
            return [selected_full_version] + regular_news
    else:
        # 没有完整版，返回所有普通新闻（6点播出期间的片段）
        print(f"没有完整版，返回 {len(regular_news)} 条片段新闻")
        return regular_news


def fetch_news(max_news=100):
    """从央视API获取新闻数据（带分页），如果当天没有数据则获取昨天的"""
    all_news = []
    page_size = 50  # 每页50条
    
    # 先获取今天的新闻
    today = datetime.now().strftime("%Y%m%d")
    first_page_news, total = fetch_news_page(1, page_size, today)
    
    if total > 0:
        print(f"获取到今天的新闻，总数: {total}")
        all_news.extend(first_page_news)
    else:
        # 今天没有数据，获取昨天的
        yesterday = (datetime.now() - __import__('datetime').timedelta(days=1)).strftime("%Y%m%d")
        print(f"今天没有新闻数据，正在获取昨天的 ({yesterday})...")
        first_page_news, total = fetch_news_page(1, page_size, yesterday)
        
        if total > 0:
            print(f"获取到昨天的新闻，总数: {total}")
            all_news.extend(first_page_news)
        else:
            print("昨天也没有新闻数据")
            return []
    
    print(f"新闻总数: {total}, 已获取: {len(all_news)}")
    
    # 如果还有更多页，并行获取
    if total > page_size and len(all_news) < max_news:
        total_pages = min((total + page_size - 1) // page_size, (max_news + page_size - 1) // page_size)
        
        # 使用线程池并行获取剩余页面
        with ThreadPoolExecutor(max_workers=3) as executor:
            future_to_page = {
                executor.submit(fetch_news_page, page, page_size): page 
                for page in range(2, total_pages + 1)
            }
            
            for future in as_completed(future_to_page):
                page = future_to_page[future]
                try:
                    news_list, _ = future.result()
                    all_news.extend(news_list)
                    print(f"第 {page} 页获取完成，当前共 {len(all_news)} 条")
                except Exception as e:
                    print(f"获取第 {page} 页失败: {e}")
                
                # 如果已经获取足够多，提前退出
                if len(all_news) >= max_news:
                    break
    
    # 限制数量
    all_news = all_news[:max_news]
    
    # 筛选新闻（只保留一个时间段的内容）
    all_news = filter_news_by_time_slot(all_news)
    
    print(f"最终获取 {len(all_news)} 条新闻")
    return all_news


if __name__ == "__main__":
    news = fetch_news(max_news=100)
    print(f"\n获取到 {len(news)} 条新闻")
    print(json.dumps(news[:5], ensure_ascii=False, indent=2))  # 只打印前5条
