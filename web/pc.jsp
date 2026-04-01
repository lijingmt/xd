<%@ page language="java" contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@include file="includes/header.inc"%>
<%@include file="includes/common.inc"%>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>《仙道》- 界面选择</title>
    <%=favicon%>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font: Normal 18px "Noto Sans SC Medium", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            text-align: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }

        @media (min-width: 768px) {
            body {
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                width: 100%;
            }
        }

        .container {
            width: 100%;
            max-width: 500px;
            margin: 0 auto;
            padding: 20px;
        }

        .logo {
            width: 200px;
            height: 54px;
            margin: 0 auto 20px;
        }

        .title {
            color: #fff;
            margin-bottom: 10px;
        }

        .title h2 {
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 8px;
        }

        .title p {
            font-size: 14px;
            opacity: 0.9;
        }

        /* UI Selection Cards */
        .ui-selection {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 16px;
            padding: 25px;
            margin-bottom: 20px;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
        }

        .ui-title {
            text-align: center;
            margin-bottom: 25px;
        }

        .ui-title h2 {
            color: #333;
            font-size: 20px;
            margin-bottom: 8px;
        }

        .ui-title p {
            color: #666;
            font-size: 14px;
        }

        .ui-cards {
            display: flex;
            gap: 15px;
            margin-bottom: 20px;
        }

        .ui-card {
            flex: 1;
            padding: 20px 15px;
            border-radius: 12px;
            cursor: pointer;
            transition: all 0.3s ease;
            border: 2px solid transparent;
        }

        .ui-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
        }

        .ui-card.new-ui {
            background: linear-gradient(135deg, rgba(102, 126, 234, 0.1) 0%, rgba(118, 75, 162, 0.1) 100%);
            border-color: rgba(102, 126, 234, 0.3);
        }

        .ui-card.new-ui:hover {
            border-color: #667eea;
            background: linear-gradient(135deg, rgba(102, 126, 234, 0.2) 0%, rgba(118, 75, 162, 0.2) 100%);
        }

        .ui-card.old-ui {
            background: linear-gradient(135deg, rgba(139, 119, 101, 0.1) 0%, rgba(107, 91, 71, 0.1) 100%);
            border-color: rgba(139, 119, 101, 0.3);
        }

        .ui-card.old-ui:hover {
            border-color: #8B7765;
            background: linear-gradient(135deg, rgba(139, 119, 101, 0.2) 0%, rgba(107, 91, 71, 0.2) 100%);
        }

        .ui-card-icon {
            font-size: 36px;
            margin-bottom: 10px;
        }

        .ui-card-title {
            font-size: 16px;
            font-weight: bold;
            margin-bottom: 8px;
            color: #333;
        }

        .ui-card-desc {
            font-size: 12px;
            color: #666;
            line-height: 1.5;
        }

        .remember-choice {
            text-align: center;
            padding-top: 15px;
            border-top: 1px solid #eee;
        }

        .remember-choice label {
            color: #666;
            font-size: 13px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }

        .remember-choice input[type="checkbox"] {
            width: 16px;
            height: 16px;
            cursor: pointer;
        }

        /* Old Login Form */
        .old-login-form {
            display: none;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 16px;
            padding: 25px;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
        }

        .old-login-form h2 {
            text-align: center;
            margin-bottom: 20px;
            color: #333;
        }

        .back-link {
            text-align: center;
            margin-bottom: 20px;
        }

        .back-link a {
            color: #667eea;
            text-decoration: none;
            font-size: 14px;
        }

        .back-link a:hover {
            text-decoration: underline;
        }

        .form-group {
            margin-bottom: 15px;
        }

        .form-control {
            width: 100%;
            padding: 12px 15px;
            border: 1px solid #ddd;
            border-radius: 8px;
            font-size: 16px;
        }

        .btn {
            display: inline-block;
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            cursor: pointer;
            text-decoration: none;
            transition: all 0.3s ease;
        }

        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #fff;
        }

        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }

        .btn-secondary {
            background: #6c757d;
            color: #fff;
        }

        .btn-danger {
            background: #dc3545;
            color: #fff;
        }

        .btn-block {
            display: block;
            width: 100%;
        }

        .error-message {
            background: #f8d7da;
            color: #721c24;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 15px;
            font-size: 14px;
        }

        .btns {
            margin-top: 20px;
        }

        .btns .btn {
            margin: 5px;
        }

        /* Footer */
        .footer {
            text-align: center;
            color: rgba(255, 255, 255, 0.8);
            font-size: 12px;
            margin-top: 20px;
            padding: 15px;
        }

        .footer a {
            color: rgba(255, 255, 255, 0.9);
        }

        @media (max-width: 480px) {
            .ui-cards {
                flex-direction: column;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <img src="logo.png" class="logo" alt="仙道">
        <div class="title">
            <h2>《仙道》</h2>
            <p>原班团队，经典仙道，醇香文字</p>
        </div>

        <!-- UI Selection -->
        <div class="ui-selection" id="uiSelection">
            <div class="ui-title">
                <h2>选择游戏界面</h2>
                <p>请选择您喜欢的游戏界面风格</p>
            </div>

            <div class="ui-cards">
                <div class="ui-card new-ui" onclick="selectUI('new')">
                    <div class="ui-card-icon">🚀</div>
                    <div class="ui-card-title">新版界面</div>
                    <div class="ui-card-desc">现代化 Vue 界面</div>
                </div>

                <div class="ui-card old-ui" onclick="selectUI('old')">
                    <div class="ui-card-icon">📜</div>
                    <div class="ui-card-title">经典界面</div>
                    <div class="ui-card-desc">传统 JSP 界面</div>
                </div>
            </div>

            <div class="remember-choice">
                <label>
                    <input type="checkbox" id="rememberChoice" checked>
                    记住我的选择
                </label>
            </div>
        </div>

        <!-- Old Login Form -->
        <div class="old-login-form" id="oldLoginForm">
            <h2>账号登录</h2>
            <div class="back-link">
                <a href="javascript:void(0);" onclick="showUISelection()">← 返回界面选择</a>
            </div>

<%
String m_key = request.getParameter("m_key");
String mid = request.getParameter("mid");
if(mid==null){
	long ot = System.currentTimeMillis();
	mid=String.valueOf(ot);
}
if(m_key==null){
	long ot = System.currentTimeMillis();
	m_key=String.valueOf(ot);
}

String z = (String)request.getParameter("z");
if(z==null)
	z=(String)request.getSession().getAttribute("z");
else
	request.getSession().setAttribute("z",z);

String error_str = request.getParameter("err");
String p_user = request.getParameter("_user");
String p_pswd = request.getParameter("_pswd");
if(p_user == null)
	p_user = "";
if(p_pswd == null)
	p_pswd = "";

	if("1".equals(error_str))
		out.print("<div class='error-message'>友情提示：用户名和密码不能为空，请修改后重试</div>");
	else if("2".equals(error_str))
		out.print("<div class='error-message'>友情提示：为了你的安全，用户名和密码不能少于2个字符，请修改后重试</div>");
	else if("3".equals(error_str))
		out.print("<div class='error-message'>友情提示：用户名和密码只能是大小写字母或数字，请修改后重试</div>");
	else if("5".equals(error_str))
		out.print("<div class='error-message'>友情提示：游戏账号和密码必须是2~12位的英文或者数字，或者两者的组合</div>");
	else if("4".equals(error_str))
		out.print("<div class='error-message'>友情提示：您输入的用户名和密码认证失败或有人正在使用该帐号</div>");
	else if("6".equals(error_str))
		out.print("<div class='error-message'>友情提示：您输入的用户名和密码认证失败，是否需要找回密码？</div>");
	else if("7".equals(error_str))
		out.print("<div class='error-message'>友情提示：系统犯晕了，请通知管理员</div>");
%>
            <form action="./entrycheck.jsp" id="loginForm" method="post">
                <input type="hidden" name="game_fg" id="game_fg" value="<%=game_pre%>">
                <div class="form-group">
                    <label for="zoneSelect" style="display:block;margin-bottom:5px;color:#666;font-size:14px;">选择区服</label>
                    <select id="zoneSelect" class="form-control" onchange="updateZone()">
                        <option value="xd01">01区</option>
                        <option value="xd02">02区</option>
                    </select>
                </div>
                <div class="form-group">
                    <input type="text" class="form-control" name="_user" value="<%=p_user%>" placeholder="输入账号(不超过13位英文或数字)">
                </div>
                <div class="form-group">
                    <input type="password" class="form-control" name="_pswd" value="<%=p_pswd%>" placeholder="输入密码(不超过13位英文或数字)">
                </div>
                <div class="btns">
                    <button type="submit" class="btn btn-primary btn-block">登录游戏</button>
                    <a class="btn btn-danger btn-block" style="margin-top:10px;" href="./regnew.jsp?<%=paraStringESC%>">注册账号</a>
                    <a class="btn btn-secondary btn-block" style="margin-top:10px;" href="pc_dark.jsp">黑暗主题</a>
                </div>
            </form>
        </div>

        <div class="footer">
            <p>注：所有游戏为测试版本，均无充值付费接口</p>
            <p>本游戏仅在非中国地区运营，请遵守本地法律使用本游戏服务</p>
            <p>Copyright © 2022, COOLIT, Co,. Ltd. All Rights Reserved.</p>
        </div>
    </div>

<script>
    // Update zone selection
    function updateZone() {
        var zone = document.getElementById('zoneSelect').value;
        document.getElementById('game_fg').value = zone;
        // Save to localStorage for persistence
        localStorage.setItem('mud_zone_choice', zone);
    }

    // Load saved zone choice
    function loadSavedZone() {
        var savedZone = localStorage.getItem('mud_zone_choice');
        if (savedZone) {
            document.getElementById('zoneSelect').value = savedZone;
            document.getElementById('game_fg').value = savedZone;
        }
    }

    // Check saved UI choice
    function checkSavedUI() {
        // Check URL parameter FIRST (优先检查 URL 参数，避免循环跳转)
        var urlParams = new URLSearchParams(window.location.search);
        var uiParam = urlParams.get('ui');
        if (uiParam === 'back') {
            localStorage.removeItem('mud_ui_choice');
            localStorage.removeItem('mud_ui_choice_time');
            // 确保显示界面选择页面
            document.getElementById('uiSelection').style.display = 'block';
            document.getElementById('oldLoginForm').style.display = 'none';
            return false;
        }

        var savedUI = localStorage.getItem('mud_ui_choice');
        var savedTime = localStorage.getItem('mud_ui_choice_time');

        // If saved choice exists and is within 30 days, redirect directly
        if (savedUI && savedTime) {
            var daysSince = (Date.now() - parseInt(savedTime)) / (1000 * 60 * 60 * 24);
            if (daysSince < 30) {
                if (savedUI === 'new') {
                    window.location.href = 'web_vue/index.html';
                    return true;
                } else if (savedUI === 'old') {
                    document.getElementById('uiSelection').style.display = 'none';
                    document.getElementById('oldLoginForm').style.display = 'block';
                    return true;
                }
            }
        }

        return false;
    }

    // Select UI
    function selectUI(ui) {
        var remember = document.getElementById('rememberChoice').checked;

        if (ui === 'new') {
            if (remember) {
                localStorage.setItem('mud_ui_choice', 'new');
                localStorage.setItem('mud_ui_choice_time', String(Date.now()));
            } else {
                localStorage.removeItem('mud_ui_choice');
                localStorage.removeItem('mud_ui_choice_time');
            }
            window.location.href = 'web_vue/index.html';
        } else if (ui === 'old') {
            if (remember) {
                localStorage.setItem('mud_ui_choice', 'old');
                localStorage.setItem('mud_ui_choice_time', String(Date.now()));
            } else {
                localStorage.removeItem('mud_ui_choice');
                localStorage.removeItem('mud_ui_choice_time');
            }
            document.getElementById('uiSelection').style.display = 'none';
            document.getElementById('oldLoginForm').style.display = 'block';
            // Load saved zone selection when showing old login form
            loadSavedZone();
        }
    }

    // Show UI selection
    function showUISelection() {
        document.getElementById('oldLoginForm').style.display = 'none';
        document.getElementById('uiSelection').style.display = 'block';
    }

    // Check on page load
    window.onload = function() {
        loadSavedZone();
        checkSavedUI();
    };
</script>

<!-- Translation plugin integration -->
<div class="translate-area" style="width: 100%; text-align: center; margin-top: 15px; color: rgba(255,255,255,0.7); font-size: 11px;">
  <script src="includes/translate.js"></script>
  <script>
    translate.language.setLocal('chinese_simplified');
    translate.service.use('client.edge');
    translate.setAutoDiscriminateLocalLanguage();
    translate.execute();
  </script>
</div>

</body>
</html>
