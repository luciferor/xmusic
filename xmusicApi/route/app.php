<?php
// +----------------------------------------------------------------------
// | ThinkPHP [ WE CAN DO IT JUST THINK ]
// +----------------------------------------------------------------------
// | Copyright (c) 2006~2018 http://thinkphp.cn All rights reserved.
// +----------------------------------------------------------------------
// | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
// +----------------------------------------------------------------------
// | Author: liu21st <liu21st@gmail.com>
// +----------------------------------------------------------------------
use think\facade\Route;

//路由分组 | 访问方式：domain/app/hello
Route::group('app', function () {
    Route::rule('code', 'Users/userCheckcodeRegister', 'POST|OPTIONS'); //获取验证码
    Route::rule('register', 'Users/userRegister', 'POST|OPTIONS'); //注册
    Route::rule('login', 'Users/userLogin', 'POST|OPTIONS'); //登录
    Route::rule('oss', 'Oss/oss', 'POST|GET|OPTIONS'); //上传文件
    Route::rule('updateinfo', 'Users/updateUserinfos', 'POST|OPTIONS')->middleware(\app\middleware\Check::class); //更新用户信息
    Route::rule('getuserinfo', 'Users/getUserinfos', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //获取用户信息
    Route::rule('openaisingle', 'Openai/openaiSingle', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //api
    Route::rule('addtodo', 'Todo/addTodo', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //添加专注
    Route::rule('gettodolist', 'Todo/getTodoList', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //获取专注列表
    Route::rule('gettododetail', 'Todo/getTodoDetail', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //获取专注详情
    Route::rule('doneTodo', 'Todo/doneTodo', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //完成专注
    Route::rule('sorttodo', 'Todo/sorttodo', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //专注排序
    Route::rule('getsession', 'Openai/getSession', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //获取聊天记录
    Route::rule('newsession', 'Openai/newSession', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //新增更新记录
    Route::rule('newinteligenagent', 'Openai/newIntelligenAgent', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //新增智能体
    Route::rule('getinteligenagent', 'Openai/getIntelligenAgent', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //查询智能体
    Route::rule('istopagent', 'Openai/istop', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //置顶智能体
    Route::rule('deleteagent', 'Openai/deleteagent', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //删除智能体
    Route::rule('clearchat', 'Openai/clearChat', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //删除智能体
    Route::rule('ranking', 'Users/getRanking', 'POST|GET|OPTIONS')->middleware(\app\middleware\Check::class); //排行榜
    //以下是新项目接口
    Route::rule('deepseek','Deepseek/chat',"POST|GET|OPTIONS");//deepseek
    Route::rule('test','Deepseek/test',"POST|GET|OPTIONS");//测试esp
})->allowCrossDomain([
            'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Credentials' => 'true',
            'Access-Control-Max-Age' => 600,
            'Access-Control-Allow-Headers' => '*,X-Requested-With,content-type,Origin,Accept,SIGN,TIME,Authorization,Time-Rubbing,Encrypted-Code,Referer,User-Agent',
        ]);

// Route::miss('Miss/index');

// Route::get('hello', 'Index/hello','POST')->allowCrossDomain();
