function showblog(){
    $("#blog_container").css("display","inherit");
    $("#blog_container").addClass("animated slideInLeft");
    setTimeout(function(){
        $("#blog_container").removeClass("animated slideInLeft");
    },800);
}
function closeblog(){
    $("#blog_container").addClass("animated slideOutLeft");
    setTimeout(function(){
        $("#blog_container").removeClass("animated slideOutLeft");
        $("#blog_container").css("display","none");
    },800);
}
function showwork(){
    $("#work_container").css("display","inherit");
    $("#work_container").addClass("animated slideInRight");
    setTimeout(function(){
        $("#work_container").removeClass("animated slideInRight");
    },800);
}
function closework(){
    $("#work_container").addClass("animated slideOutRight");
    setTimeout(function(){
        $("#work_container").removeClass("animated slideOutRight");
        $("#work_container").css("display","none");
    },800);
}
function showcareer(){
    $("#career_container").css("display","inherit");
    $("#career_container").addClass("animated slideInUp");
    setTimeout(function(){
        $("#career_container").removeClass("animated slideInUp");
    },800);
}
function closecareer(){
    $("#career_container").addClass("animated slideOutDown");
    setTimeout(function(){
        $("#career_container").removeClass("animated slideOutDown");
        $("#career_container").css("display","none");
    },800);
}
setTimeout(function(){
    $("#loading").addClass("animated fadeOut");
    setTimeout(function(){
      $("#loading").removeClass("animated fadeOut");
      $("#loading").css("display","none");
      $("#box").css("display","none");
      $("#blog").removeClass("animated fadeIn");
      $("#career").removeClass("animated fadeIn");
      $("#work").removeClass("animated fadeIn");
    },1000);
},1500);
