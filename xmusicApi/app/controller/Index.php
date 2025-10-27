<?php
namespace app\controller;

use app\BaseController;
use think\facade\Db;
use think\facade\Request;

class Index extends BaseController
{
    public function index()
    {
        var_dump(phpinfo());
        return handleResult(200,Db::table('sys_member_users')->select(),true);
    }

    public function hello($name = 'ThinkPHP6')
    {
        $info = Request::header();
        return json($info);
    }
}
