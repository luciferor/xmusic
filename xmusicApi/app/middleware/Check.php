<?php
declare (strict_types = 1);

namespace app\middleware;
use think\facade\Request;

class Check
{
    /**
     * 处理请求
     */
    public function handle($request, \Closure $next)
    {
        $token = Request::header('authorization')??false;
        if($token){
            return $next($request);
        }else{
            return handleResult(201,'token过期,或不存在~',false);
        }
    }
}
