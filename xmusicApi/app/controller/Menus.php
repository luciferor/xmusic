<?php
namespace app\controller;

use app\BaseController;
use think\facade\Db;
use think\facade\Request;

class Menus extends BaseController
{
    public function index()
    {
        var_dump(Db::table('sys_users')->select());
        return '<h1>Hello!</h1>';
    }

    public function hello($name = 'ThinkPHP6')
    {
        $info = Request::header();
        return json($info);
    }
}
