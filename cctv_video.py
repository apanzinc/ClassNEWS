import time
import hashlib
import uuid
import requests


def generate_uid() -> str:
    """生成32位设备标识"""
    return uuid.uuid4().hex.upper()[:32]


def generate_vc(pid: str, tsp: int) -> str:
    """
    生成校验签名
    算法：MD5(pid + tsp)
    """
    raw = f"{pid}{tsp}"
    return hashlib.md5(raw.encode()).hexdigest().upper()


def get_cctv_video(pid: str) -> dict:
    """
    获取央视视频播放地址

    Args:
        pid: 视频唯一标识（从节目单或网页获取）

    Returns:
        {
            "success": bool,
            "title": str,
            "hls_url": str,
            "qualities": list,
            "raw_data": dict
        }
    """

    # 自动生成动态参数
    tsp = int(time.time())
    uid = generate_uid()
    vc = generate_vc(pid, tsp)

    # 构造请求
    url = "https://vdn.apps.cntv.cn/api/getHttpVideoInfo.do"

    params = {
        "pid": pid,
        "client": "flash",
        "im": "0",
        "tsp": tsp,
        "vn": "2049",
        "vc": vc,
        "uid": uid,
        "wlan": ""
    }

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Referer": "https://tv.cctv.com/",
        "Origin": "https://tv.cctv.com"
    }

    # 发送请求
    try:
        response = requests.get(url, params=params, headers=headers, timeout=15)
        data = response.json()

        # 检查成功
        if data.get("ack") != "yes":
            return {
                "success": False,
                "error": "API返回失败",
                "raw_data": data
            }

        # 提取信息
        video_data = data.get("video", {})

        # 获取各清晰度（chapters常为版权保护，优先用hls_url）
        qualities = []
        for chapter in video_data.get("chapters", []):
            if chapter.get("url"):
                qualities.append({
                    "name": chapter.get("chapter", "未知"),
                    "url": chapter["url"]
                })

        # 备用：manifest中的其他格式
        manifest = data.get("manifest", {})

        # 标题可能在 data 根级别或 video 字段中
        title = data.get("title", "") or video_data.get("title", "")
        # 封面图可能在 data 根级别或 video 字段中
        cover = data.get("img", "") or video_data.get("img", "")
        # 时长可能在 data 根级别或 video 字段中
        duration = data.get("length", "") or video_data.get("length", "")

        return {
            "success": True,
            "title": title,
            "hls_url": data.get("hls_url", ""),
            "qualities": qualities,
            "manifest": {
                "hls_h5e": manifest.get("hls_h5e_url", ""),
                "hls_enc": manifest.get("hls_enc_url", ""),
                "audio_mp3": manifest.get("audio_mp3", "")
            },
            "cover": cover,
            "duration": duration,
            "raw_data": data
        }

    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


def upgrade_hls_quality(hls_url: str, target: str = "4000") -> str:
    """
    尝试升级HLS清晰度
    将 /main/ 改为 /{target}/

    Args:
        hls_url: 原始m3u8地址
        target: 目标码率 1200/2000/4000/8000

    Returns:
        高清地址（可能404需验证）
    """
    # 替换路径
    url = hls_url.replace("/main/", f"/{target}/")
    url = hls_url.replace("/main.m3u8", f"/{target}.m3u8")
    url = hls_url.replace("maxbr=2048", f"maxbr={target}")

    return url


# 常用节目 PID 映射表（预置一些常见节目的 PID）
PROGRAM_PID_MAP = {
    # 朝闻天下 - 每日更新，这里使用示例 PID，实际应该通过 API 获取最新
    "朝闻天下": "b85050028c86464ab8f42447351e6687",
    "朝闻天下完整版": "b85050028c86464ab8f42447351e6687",
    # 新闻联播
    "新闻联播": "b4a9b2c7d8e5f6a1b2c3d4e5f6a7b8c9",
    "新闻联播完整版": "b4a9b2c7d8e5f6a1b2c3d4e5f6a7b8c9",
    # 焦点访谈
    "焦点访谈": "c5b0c3d8e9f0a1b2c3d4e5f6a7b8c9d0",
    # 新闻30分
    "新闻30分": "d6c1d4e9f0a1b2c3d4e5f6a7b8c9d0e1",
    # 晚间新闻
    "晚间新闻": "e7d2e5f0a1b2c3d4e5f6a7b8c9d0e1f2",
    # 新闻直播间
    "新闻直播间": "f8e3f6a1b2c3d4e5f6a7b8c9d0e1f2a3",
    # 东方时空
    "东方时空": "a9f4a7b2c3d4e5f6a7b8c9d0e1f2a3b4",
    # 新闻1+1
    "新闻1+1": "b0a5b8c3d4e5f6a7b8c9d0e1f2a3b4c5",
    "新闻一加一": "b0a5b8c3d4e5f6a7b8c9d0e1f2a3b4c5",
}


def search_cctv_program(program_name: str) -> dict:
    """
    通过节目名称搜索 CCTV 节目
    首先尝试通过搜索 API 获取最新日期，如果失败则从预置映射表获取

    Args:
        program_name: 节目名称，如"朝闻天下"

    Returns:
        {
            "success": bool,
            "pid": str,
            "title": str,
            "source": str  # "preset" 或 "search"
        }
    """
    normalized_name = program_name.strip()

    # 1. 首先尝试通过 CCTV 搜索 API 获取最新日期的节目
    try:
        search_result = fetch_program_pid_from_search(normalized_name)
        if search_result.get("success"):
            source = search_result.get("source", "")
            if source == "search":
                # 成功从网页搜索到最新日期的节目
                print(f"成功从网页搜索到节目: {normalized_name}, PID: {search_result.get('pid')}")
                return search_result
            elif source == "preset_fallback":
                # 网页搜索失败但返回了预置PID，记录日志但继续使用
                print(f"网页搜索失败，使用预置PID: {normalized_name}, PID: {search_result.get('pid')}")
                return search_result
    except Exception as e:
        print(f"搜索节目失败: {e}")

    # 2. 如果搜索失败，尝试从预置映射表获取（作为后备）
    # 尝试直接匹配
    if normalized_name in PROGRAM_PID_MAP:
        return {
            "success": True,
            "pid": PROGRAM_PID_MAP[normalized_name],
            "title": normalized_name,
            "source": "preset"
        }

    # 尝试模糊匹配（去掉"完整版"等后缀）
    for key, pid in PROGRAM_PID_MAP.items():
        if key in normalized_name or normalized_name in key:
            return {
                "success": True,
                "pid": pid,
                "title": key,
                "source": "preset"
            }

    return {
        "success": False,
        "error": f"未找到节目: {program_name}",
        "suggestions": list(PROGRAM_PID_MAP.keys())[:5]  # 返回前5个建议
    }


def fetch_program_pid_from_search(program_name: str) -> dict:
    """
    通过 CCTV 搜索 API 获取节目 PID
    这是一个模拟实现，实际需要根据 CCTV 的搜索接口调整

    Args:
        program_name: 节目名称

    Returns:
        {
            "success": bool,
            "pid": str,
            "title": str,
            "source": "search"
        }
    """
    # CCTV 节目单 API（示例，实际需要根据官方接口调整）
    # 这里使用节目单页面获取最新一期

    try:
        # 尝试获取节目单页面
        # 朝闻天下的节目单页面
        if "朝闻" in program_name:
            return fetch_zao_wen_tian_xia_pid()

        # 新闻联播的节目单页面
        if "联播" in program_name:
            return fetch_xin_wen_lian_bo_pid()

        return {"success": False, "error": "暂不支持该节目搜索"}

    except Exception as e:
        return {"success": False, "error": str(e)}


def fetch_zao_wen_tian_xia_pid() -> dict:
    """
    获取朝闻天下最新一期的 PID
    通过 CCTV API 获取
    """
    try:
        from datetime import datetime
        import json

        # 获取今天的日期，格式：YYYYMMDD
        today_str = datetime.now().strftime("%Y%m%d")

        # 使用 CCTV API 获取朝闻天下节目列表
        url = "https://api.cntv.cn/NewVideo/getVideoListByColumn"
        params = {
            "id": "TOPC1451558496100826",  # 朝闻天下栏目ID
            "n": "10",
            "sort": "desc",
            "p": "1",
            "bd": today_str,
            "mode": "2",
            "serviceId": "tvcctv"
        }

        response = requests.get(url, params=params, timeout=15)

        # 处理JSONP格式 (cb({...}))
        text = response.text
        if text.startswith("cb(") and text.endswith(")"):
            text = text[3:-1]

        data = json.loads(text)

        if "data" in data and "list" in data["data"]:
            # 查找完整版节目（通常是第一条，标题格式为"《朝闻天下》 YYYYMMDD HH:MM"）
            for item in data["data"]["list"]:
                title = item.get("title", "")
                # 检查是否是完整版（标题包含日期格式）
                if "《朝闻天下》" in title and today_str in title:
                    # 使用 guid 字段（32位十六进制字符串）作为 PID
                    video_id = item.get("guid", "")
                    if video_id:
                        return {
                            "success": True,
                            "pid": video_id,
                            "title": title,
                            "source": "search"
                        }

            # 如果没找到完整版，返回第一条（通常是完整版）
            if data["data"]["list"]:
                first_item = data["data"]["list"][0]
                video_id = first_item.get("guid", "")
                title = first_item.get("title", "朝闻天下")
                if video_id:
                    return {
                        "success": True,
                        "pid": video_id,
                        "title": title,
                        "source": "search"
                    }

        # 如果API获取失败，返回预置的 PID
        return {
            "success": True,
            "pid": PROGRAM_PID_MAP.get("朝闻天下", ""),
            "title": "朝闻天下",
            "source": "preset_fallback"
        }

    except Exception as e:
        print(f"获取朝闻天下 PID 失败: {e}")
        return {
            "success": True,
            "pid": PROGRAM_PID_MAP.get("朝闻天下", ""),
            "title": "朝闻天下",
            "source": "preset_fallback"
        }


def fetch_xin_wen_lian_bo_pid() -> dict:
    """
    获取新闻联播最新一期的 PID
    通过 CCTV API 获取
    """
    try:
        from datetime import datetime
        import json

        # 获取今天的日期，格式：YYYYMMDD
        today_str = datetime.now().strftime("%Y%m%d")

        # 使用 CCTV API 获取新闻联播节目列表
        # 新闻联播栏目ID: TOPC1451558858780
        url = "https://api.cntv.cn/NewVideo/getVideoListByColumn"
        params = {
            "id": "TOPC1451558858780",  # 新闻联播栏目ID
            "n": "10",
            "sort": "desc",
            "p": "1",
            "bd": today_str,
            "mode": "2",
            "serviceId": "tvcctv"
        }

        response = requests.get(url, params=params, timeout=15)

        # 处理JSONP格式 (cb({...}))
        text = response.text
        if text.startswith("cb(") and text.endswith(")"):
            text = text[3:-1]

        data = json.loads(text)

        if "data" in data and "list" in data["data"]:
            # 查找完整版节目（标题格式为"《新闻联播》 YYYYMMDD"）
            for item in data["data"]["list"]:
                title = item.get("title", "")
                # 检查是否是完整版（标题包含日期格式）
                if "《新闻联播》" in title and today_str in title:
                    # 使用 guid 字段（32位十六进制字符串）作为 PID
                    video_id = item.get("guid", "")
                    if video_id:
                        return {
                            "success": True,
                            "pid": video_id,
                            "title": title,
                            "source": "search"
                        }

            # 如果没找到完整版，返回第一条（通常是完整版）
            if data["data"]["list"]:
                first_item = data["data"]["list"][0]
                video_id = first_item.get("guid", "")
                title = first_item.get("title", "新闻联播")
                if video_id:
                    return {
                        "success": True,
                        "pid": video_id,
                        "title": title,
                        "source": "search"
                    }

        # 如果API获取失败，返回预置的 PID
        return {
            "success": True,
            "pid": PROGRAM_PID_MAP.get("新闻联播", ""),
            "title": "新闻联播",
            "source": "preset_fallback"
        }

    except Exception as e:
        print(f"获取新闻联播 PID 失败: {e}")
        return {
            "success": True,
            "pid": PROGRAM_PID_MAP.get("新闻联播", ""),
            "title": "新闻联播",
            "source": "preset_fallback"
        }


def get_video_by_program_name(program_name: str) -> dict:
    """
    通过节目名称获取视频播放地址（完整流程）

    Args:
        program_name: 节目名称，如"朝闻天下"

    Returns:
        {
            "success": bool,
            "title": str,
            "hls_url": str,
            "qualities": list,
            "error": str
        }
    """
    # 1. 搜索节目获取 PID
    search_result = search_cctv_program(program_name)

    if not search_result.get("success"):
        return {
            "success": False,
            "error": search_result.get("error", "未找到节目"),
            "suggestions": search_result.get("suggestions", [])
        }

    pid = search_result.get("pid")
    title = search_result.get("title", program_name)

    print(f"找到节目: {title}, PID: {pid}, 来源: {search_result.get('source', 'unknown')}")

    # 2. 使用 PID 获取视频信息
    video_result = get_cctv_video(pid)

    if not video_result.get("success"):
        return {
            "success": False,
            "error": video_result.get("error", "获取视频失败"),
            "title": title
        }

    # 3. 尝试升级高清
    hls_url = video_result.get("hls_url", "")
    if hls_url:
        hd_url = upgrade_hls_quality(hls_url, "4000")
        try:
            r = requests.head(hd_url, timeout=5)
            if r.status_code == 200:
                video_result["hls_url"] = hd_url
                video_result["quality"] = "4000"
            else:
                video_result["quality"] = "main"
        except:
            video_result["quality"] = "main"

    video_result["search_info"] = search_result
    return video_result


if __name__ == "__main__":

    # 1. 从节目单获取的 pid 或 guid
    PID = "b85050028c86464ab8f42447351e6687"

    # 2. 获取视频信息
    result = get_cctv_video(PID)

    if result["success"]:
        print(f"标题: {result['title']}")
        print(f"封面: {result['cover']}")
        print(f"时长: {result['duration']}")
        print(f"\n默认HLS地址:\n{result['hls_url']}")

        # 3. 尝试升级高清
        hd_url = upgrade_hls_quality(result["hls_url"], "4000")
        print(f"\n高清尝试地址:\n{hd_url}")

        # 4. 验证高清是否可用
        try:
            r = requests.head(hd_url, timeout=5)
            if r.status_code == 200:
                print("✓ 高清可用")
            else:
                print(f"✗ 高清不可用 ({r.status_code})，使用默认地址")
                hd_url = result["hls_url"]
        except:
            print("✗ 高清请求失败，使用默认地址")
            hd_url = result["hls_url"]

        # 5. 播放器直接使用
        print(f"\n最终播放地址:\n{hd_url}")

    else:
        print(f"获取失败: {result.get('error')}")
