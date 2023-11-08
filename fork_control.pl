#! /usr/bin/perl
############################################################
#      Copyright (C) Hangzhou
#      作    者: 葛文龙
#      通讯邮件: gwl9505@163.com
#      脚本名称: fork_control.pl
#      版   本: 2.0
#      创建日期: 2022年03月26日
############################################################
use feature ':all';

use Getopt::Long;
use vars qw($in_run $max_threads $no_warning $help);
GetOptions(
    "i=s" => \$in_run,
    "m:s" => \$max_threads,
    "n" => \$no_warning,

    "h" => \$help
);
&HELP if ($help);

sub HELP{
    say STDOUT "脚本功能：";
    say STDOUT "\t逐行读入sh文件的命令，控制同时运行的最大条目数\n";
    print STDOUT "选项\n";
    say STDOUT "\t-i : 输入sh文件";
    say STDOUT "\t-m : 最大运行进程数，默认为3";
    say STDOUT "\t-n : 无需参数，开启此条目可以无视进程数过多的警告";
    exit;
}

use threads;
use Thread::Semaphore;

$max_threads||=3;
if($max_threads > 10 && $no_warning == 0){
    say "注意：设置进程数大于 10 ，真的要设置这么多吗？";
    say "输入 y 确认以继续进行,或者输入任意数字修改进程数,否则将被修正为5";
    my $jud=<STDIN>;
    chomp $jud;
    if($jud=~/\A\d+\z/){$max_threads=$jud;}elsif($jud ne "y"){
        $max_threads=5;
    }
    my @cpu_info=`lscpu`;
    my $cpu_n;
    if($cpu_info[3]=~/([\d]*)\n/){$cpu_n=$1/2;}
    if($cpu_n < 10 || $max_threads > $cpu_n){
        say "警告:\n设置的进程数 $max_threads 已经大于最大cpu核心数一半($cpu_n),可能造成严重卡顿,程序将于5秒后开始运行";
        $|=1;
	for(-5..-0){
		print "\r","倒计时 ",abs;
		sleep 1;
	}
	$|=0;
    }
    AB:1;
}

my $semaphore=new Thread::Semaphore($max_threads);
open IN,'<',$in_run;
my @run_file=<IN>;
chomp @run_file;
close IN;
my $run_num;
$|=1;
while(){
    if($run_num>$#run_file){
        last;
    }
    $run_num+=1;
    my $run=$run_file[$run_num-1];
    if($run_num > $max_threads){
        print "\r",$run_num-$max_threads,"/",$#run_file+1;
    }
    $semaphore->down();
    my $thread=threads->new(\&Work,$run,$run_num);
    $thread->detach();
}
my $max_cope=$max_threads;
&Waitquit;

sub Work{
    `$_[0]`;
    $semaphore->up();
}

sub Waitquit{
    my $num=0;
    while($num<$max_threads){
        $semaphore->down();
        $num++;
        $max_cope-=1;
        print "\r",$run_num-$max_cope,"/",$#run_file+1;
    }
    $|=0;
    print "\n所有 ",$#run_file+1," 条任务都已经结束\n" if($no_warning == 0);
}
