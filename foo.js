function draw() {
var canvas = document.getElementById("canvas");
var ctx = canvas.getContext("2d");
ctx.translate(0,0);
ctx.rect(5, 5, 490,340);
ctx.clip();
ctx.fillStyle = "rgba(255, 255, 0, 1.00);"
ctx.beginPath();
ctx.fillRect(5,5,500,350);
// Begin Top Border
ctx.beginPath();
ctx.fillStyle = "rgba(255, 0, 255, 1.00);"
ctx.strokeStyle = "rgba(255, 0, 255, 1.00);"
ctx.lineWidth = 2;
ctx.lineCap = 'butt';
ctx.lineJoin = 'miter';
ctx.moveTo(5,6);
ctx.lineTo(500, 6);
ctx.stroke();
// End Top Border
// Begin Right Border
ctx.beginPath();
ctx.fillStyle = "rgba(0, 0, 255, 1.00);"
ctx.strokeStyle = "rgba(0, 0, 255, 1.00);"
ctx.lineWidth = 3;
ctx.lineCap = 'butt';
ctx.lineJoin = 'miter';
ctx.moveTo(493.5,5);
ctx.lineTo(493.5,345);
ctx.stroke();
// End Right Border
}
