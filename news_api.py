import requests
import json
import random
import re
from pathlib import Path
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

# 加载 API 配置
def load_api_config():
    """加载 API 配置文件"""
    config_path = Path(__file__).parent / "api_config.json"
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except:
        # 如果配置文件不存在或解析失败，使用默认配置
        return {
            "news_api": {
                "base_url": "https://api.cntv.cn/NewVideo/getVideoListByColumn",
                "timeout": 15,
                "default_page_size": 50,
                "params": {
                    "id": "TOPC1451558496100826",
                    "sort": "desc",
                    "mode": "2",
                    "serviceId": "tvcctv"
                }
            }
        }

API_CONFIG = load_api_config()

def fetch_news_page(page=1, page_size=50, date=None):
    """从央视 API 获取单页新闻数据"""
    # 从配置中获取 API 参数
    news_api_config = API_CONFIG.get("news_api", {})
    url = news_api_config.get("base_url", "https://api.cntv.cn/NewVideo/getVideoListByColumn")
    timeout = news_api_config.get("timeout", 15)
    default_params = news_api_config.get("params", {})
    
    # 获取当前日期
    if date is None:
        date = datetime.now().strftime("%Y%m%d")
    
    # 构建请求参数
    params = {
        **default_params,  # 使用配置中的默认参数
        "n": str(page_size),  # 每页数量
        "p": str(page),
        "bd": date,  # 指定日期
    }
    
    try:
        response = requests.get(url, params=params, timeout=timeout)
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
    根据当前时间选择对应的完整版新闻
    只显示当前时间段的完整版 + 它后面的所有普通新闻
    比如 8:30 只显示 8:00 的完整版和它的片段
    """
    if not news_list:
        return []
    
    # 找出所有完整版及其索引位置
    full_version_indices = []
    for i, news in enumerate(news_list):
        if news.get("isFullVersion"):
            full_version_indices.append(i)
    
    if not full_version_indices:
        # 没有完整版，返回所有新闻
        print(f"没有完整版，返回 {len(news_list)} 条片段新闻")
        return news_list
    
    # 获取当前时间，找到对应的完整版
    from datetime import datetime
    current_hour = datetime.now().hour
    
    # 找到当前时间对应的完整版（小时数 <= 当前小时的最新版）
    # 比如 8:30，应该找 8:00 的完整版
    selected_full_idx = None
    for full_idx in reversed(full_version_indices):
        full_version = news_list[full_idx]
        # 从标题或时间中提取小时数
        title = full_version.get('title', '')
        # 尝试从标题中解析小时数，例如 "朝闻天下 20240101 08:00"
        import re
        time_match = re.search(r'(\d{2}):\d{2}', title)
        if time_match:
            video_hour = int(time_match.group(1))
            if video_hour <= current_hour:
                selected_full_idx = full_idx
                break
    
    # 如果没有找到合适的完整版（比如当前时间是 5:00，但最早是 6:00 的完整版）
    # 或者当前是凌晨时段（0-5 点），显示最新的完整版（昨天的最后一档）
    if selected_full_idx is None:
        # 凌晨时段，使用最后一个完整版（最新的）
        selected_full_idx = full_version_indices[-1]
        print(f"当前时间 {current_hour}:00 是凌晨时段，使用最新完整版：{news_list[selected_full_idx].get('title', 'Unknown')}")
    else:
        print(f"当前时间 {current_hour}:00，选择完整版索引：{selected_full_idx}")
    
    # 提取这组新闻：完整版 + 后面的所有普通新闻（直到下一个完整版或列表末尾）
    next_full_idx = full_version_indices[full_version_indices.index(selected_full_idx) + 1] \
                    if full_version_indices.index(selected_full_idx) + 1 < len(full_version_indices) \
                    else len(news_list)
    
    group = news_list[selected_full_idx:next_full_idx]
    
    full_version = group[0]
    regular_count = len(group) - 1
    
    print(f"完整版：{full_version['title']} - 包含 {regular_count} 条普通新闻")
    
    # 为这组的所有新闻添加分组标识
    for news in group:
        news['groupIndex'] = 0  # 只有一组，所以都是 0
    
    print(f"筛选完成：1 个完整版，共 {len(group)} 条新闻")
    return group



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
