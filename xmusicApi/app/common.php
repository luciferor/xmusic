<?php
// 应用公共文件
use \Firebase\JWT\JWT;
use Firebase\JWT\Key;
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;
use think\facade\Db;
use think\facade\Request;

//返回json格式化后的内容
function handleResult($code,$message,$status){
    return json(['code'=>$code,'message'=>$message,'status'=>$status]);
}

//验证请求的合法性
function checkAuthorHandler($arr,$checkCode,$timeStr){
    if (!empty($arr)) {
        $temArr = [];
        foreach ($arr as $key => $value) {
            array_push($temArr, ucfirst($key));
        }
        natsort($temArr);
        $result = md5($timeStr . implode($temArr) . $timeStr . 'Dias Software Inc.');
        return $result === $checkCode;
    } else {
        $result = md5($timeStr . '' . $timeStr . 'Dias Software Inc.');
        return $result === $checkCode;
    }
}

/**
 *生成随机验证码
*/
function NewCreateRandomAuthorCode($count)
{
    // 密码字符集，可任意添加你需要的字符
    $chars = array(
        'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
        'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's',
        't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D',
        'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
        'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
    );
    // 在 $chars 中随机取 $length 个数组元素键名
    $keys = array_rand($chars, $length = $count);
    $code = '';
    for ($i = 0; $i < $length; $i++) {
        // 将 $length 个数组元素连接成字符串
        $code .= $chars[$keys[$i]];
    }
    return strtoupper($code);
}

/**
 *生成数字验证码
*/
function RandomNumberCode($count)
{
    $min = pow(10, $count - 1); // 最小值
    $max = pow(10, $count) - 1; // 最大值
    return rand($min, $max); // 生成随机数
}

//生成验签
function signToken($data) :string
{
    $key='Dias Sofatware Inc.';         //这里是自定义的一个随机字串，应该写在config文件中的，解密时也会用，相当于加密中常用的 盐-salt
    $token=array(
        "iss"=>$key,                    //签发者 可以为空
        "aud"=>'',                      //面象的用户，可以为空
        "iat"=>time(),                  //签发时间
        "nbf"=>time()+3,                //在什么时候jwt开始生效  （这里表示生成100秒后才生效）
        "exp"=> time()+720000,            //token 过期时间
        "data"=>$data                   //记录的userid的信息，这里是自已添加上去的，如果有其它信息，可以再添加数组的键值对
    );
    return JWT::encode($token, $key, "HS384");  //根据参数生成了token，可选：HS256、HS384、HS512、RS256、ES256等
}

//验证token
function checkToken($token) :array
{
    $key='Dias Sofatware Inc.';
    $status=array("code"=>2);
    try {
        JWT::$leeway = 60;//当前时间减去60，把时间留点余地
        $decoded = JWT::decode($token, new Key($key, 'HS384') ); //同上的方式，这里要和签发的时候对应
        $arr = (array)$decoded;
        $res['code']=200;
        $res['data']=$arr['data'];
        $res['data'] = json_decode(json_encode($res['data']),true);//将stdObj类型转换为array
        return $res;
    } catch(\Firebase\JWT\SignatureInvalidException $e) { //签名不正确
        $status['msg']="签名不正确";
        return $status;
    }catch(\Firebase\JWT\BeforeValidException $e) { // 签名在某个时间点之后才能用
        $status['msg']="token失效";
        return $status;
    }catch(\Firebase\JWT\ExpiredException $e) { // token过期
        $status['msg']="token失效";
        return $status;
    }catch(Exception $e) { //其他错误
        $status['msg']="未知错误";
        return $status;
    }
}

//发送邮件
function sendEmail($title,$message,$address){
    //获取配置好的邮件服务器信息 ｜ 目前腾讯企业邮箱
    $arr = Db::table('sys_emails')->find();
    $mail = new PHPMailer(true);
    // try {
    //     //Server settings
    //     $mail->SMTPDebug = SMTP::DEBUG_SERVER;                      //Enable verbose debug output
    //     $mail->isSMTP();                                            //Send using SMTP
    //     $mail->Host       = $arr['email_smtp'];                     //Set the SMTP server to send through
    //     $mail->SMTPAuth   = true;                                   //Enable SMTP authentication
    //     $mail->Username   = $arr['email_acount'];                     //SMTP username
    //     $mail->Password   = $arr['email_password'];                               //SMTP password
    //     $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;            //Enable implicit TLS encryption
    //     $mail->Port       = $arr['email_port'];                                    //TCP port to connect to; use 587 if you have set `SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS`

    //     //Recipients
    //     $mail->setFrom('root@dsnbc.com', 'Mailer');     //Add a recipient
    //     $mail->addAddress($address,'aaaaaaaaa');

    //     //Content
    //     $mail->isHTML(true);                                  //Set email format to HTML
    //     // $mail->CharSet = 'utf8';
    //     $mail->Subject = $title;
    //     $mail->Body    = $message;
    //     $mail->AltBody = $message;

    //     $mail->send();
    //     return '邮件发送成功~';
    // } catch (Exception $e) {
    //     return "邮件发送失败了~: {$mail->ErrorInfo}";
    // }

    try {
        $mail->isSMTP(); // 使用SMTP服务发送邮件
        $mail->SMTPAuth = true; // 启用 SMTP 认证
        $mail->SMTPSecure = 'ssl';
        $mail->Host = $arr['email_smtp']; // SMTP 服务器
        $mail->Port = $arr['email_port']; // SMTP服务器的端口号
        $mail->Username = $arr['email_acount']; // SMTP账号
        $mail->Password = $arr['email_password']; // SMTP密码

        $mail->From = 'root@dsnbc.com'; // 发件人邮箱
        $mail->FromName = '荧惑之星'; // 发件人名称
        $mail->isHTML(true); // 邮件正文是否为html编码
        $mail->CharSet = 'utf-8'; // 设置邮件字符集
        $mail->addAddress($address); // 收件人邮箱地址
        $mail->Subject = $title; // 邮件标题
        $mail->Body = $message; // 邮件内容

        return $mail->send();
    } catch (\Throwable $th) {
        //throw $th;
        return '发送失败'.$th;
    }   
}

//解密token并返回数据
function extendTokenInfo(){
    $token = Request::header()['authorization'];
    if($token){
       return checkToken($token)['data'];
    }else{
        return [];
    }
}