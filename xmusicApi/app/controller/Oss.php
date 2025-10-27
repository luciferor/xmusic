<?php
namespace app\controller;

use app\BaseController;
use think\facade\Db;
use think\facade\Request;
use think\facade\Filesystem;

class Oss extends BaseController
{
    public function index()
    {
    }

    //上传图片
    public function oss()
    {
        $file = request()->file('file');
        try {
            validate(['image' => 'fileExt:jpg|image,png|image,gif|image,jpeg|image'])->check(['file', $file]);
            // 上传到本地服务器
            $info = Filesystem::disk('public')->putFile('images', $file);
            return handleResult(200, $info, true);
        } catch (\Throwable $th) {
            return handleResult(500, $th, false);
        }

    }
}
