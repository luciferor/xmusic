<?php
namespace app\controller;

use app\BaseController;

class Miss extends BaseController
{
    public function index()
    {
        $rs = [
            "status"  => false,
            "message" => '请求错误 Miss页面',
            "code"    => 500,
        ];
        return json($rs);
    }
}
