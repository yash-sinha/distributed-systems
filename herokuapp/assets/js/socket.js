// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channels, the first step is to import Socket
// and connect at the socket path in "lib/web/endpoint.ex":
import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

// When you connect, you'll often need to authenticate the client.
// For example, imagine you have an authentication plug, `MyAuth`,
// which authenticates the session and assigns a `:current_user`.
// If the current user exists you can assign the user's token in
// the connection for use in the layout.
//
// In your "lib/web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "lib/web/templates/layout/app.html.eex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/2" function
// in "lib/web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, pass the token on connect as below. Or remove it
// from connect if you don't care about authentication.

socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("twitter", {})

// $(document).ready(function() { channel.push('update_socket', { username: userID });
// });
let myid = "";
function getmyid() {
  var url = window.location.href;
  var params = url.split('/');
  return params[params.length-1];
}

$(document).ready(function() {
  channel.push('update_socket', {username: getmyid()});
  channel.push('updatemyfeed', {username: getmyid()});
});

if(document.getElementById("signup"))         // use this if you are using id to check
{
  let new_username = document.querySelector('#username');
  let new_password    = document.querySelector('#password');
  document.getElementById("signup").onclick = function() {
    if(new_password.value != "" &&   new_username.value != ""){
      channel.push('register_account', { username: new_username.value, password: new_password.value });
    }
    else{
      alert("Empty username or password not allowed")
    }
    new_password.value = "";
    new_username.value = "";
  };
}

channel.on('signupres', payload => {
  let res = payload['res'];
  let user = payload['user'];
  console.log("res", res);
  if (res == true) {
    alert('User ' +user + ' signed up. Please login now!');
  }
  else {
    alert('User exists');
  }
});

channel.on('followres', payload => {
  let res = payload['status'];
  alert(res);
  let tofollow = document.querySelector('#tofollow');
  tofollow.value = "";
});

if(document.getElementById("signin"))         // use this if you are using id to check
{
  let username = document.querySelector('#username');
  let password    = document.querySelector('#password');
  document.getElementById("signin").onclick = function() {
    channel.push('signin', { username: username.value, password: password.value });
  };

  document.getElementById("password")
    .addEventListener("keyup", function(event) {
    event.preventDefault();
    if (event.keyCode === 13) {
        document.getElementById("signin").click();
    }
  });
}

channel.on('signin', payload => {
  let username = document.querySelector('#username');
  let password    = document.querySelector('#password');
  //alert(`${payload.login_status}`)
  // list.append(`<b>${"Registered:" || 'Anonymous'}:</b> payload["status"]<br>`);
  // list.prop({scrollTop: list.prop("scrollHeight")});
  if (payload["status"] == "Logged in") {
    window.location.href = 'https://uftwitter.herokuapp.com/home' + '/' + username.value;
  }
  else{
    alert(payload["status"]);
    password.value = "";
    username.value = "";
  }

});

if(document.getElementById("btnTweet"))         // use this if you are using id to check
{
  let desc    = document.querySelector('#tweetContent');
  var userID =  getmyid()
  document.getElementById("btnTweet").onclick = function() {
    if(desc.value != ""){
      channel.push('tweet', { desc: desc.value , username: userID });
    }
  desc.value = "";
  };
  document.getElementById("tweetContent")
    .addEventListener("keyup", function(event) {
    event.preventDefault();
    if (event.keyCode === 13) {
        document.getElementById("btnTweet").click();
    }
  });
}

if(document.getElementById("btnFollow"))         // use this if you are using id to check
{
  let tofollow = document.querySelector('#tofollow');
  //let username_orig = Request.querystring["temp"];
  //var text =
  console.log("myid " + getmyid());
  document.getElementById("btnFollow").onclick = function() {
    if(tofollow!=""){
      channel.push('follow', { tofollow: tofollow.value, me: getmyid() });
    }
  };

  document.getElementById("tofollow")
    .addEventListener("keyup", function(event) {
    event.preventDefault();
    if (event.keyCode === 13) {
        document.getElementById("btnFollow").click();
    }
  });
}

if(document.getElementById("logoutbtn"))         // use this if you are using id to check
{
  document.getElementById("logoutbtn").onclick = function() {
    channel.push('remove_socket', { username: getmyid() });
  };
}

channel.on('redirect', payload => {
  window.location.href = 'https://uftwitter.herokuapp.com/'
});

channel.on('gettweet', payload => {
  // alert("New tweet");
  console.log(payload);
  let tweet_list    = $('#tweet-list');
  var btn = document.createElement("INPUT");
  btn.setAttribute('type', 'radio');
  btn.setAttribute('name', 'radioTweet');
  btn.setAttribute('user', `${payload.tweeter}`);
  btn.setAttribute('tweet', `${payload.tweetText}`);
  btn.setAttribute('tweetID', `${payload.tweetID}`);
  console.log(payload);
  //btn.innerHTML = 'RETWEET';
  if(`${payload.isRetweet}` == "false")
  {
    tweet_list.prepend(` <b>${payload.time}: ${payload.tweeter}:</b> ${payload.tweetText}<br>`);
  }
  if(`${payload.isRetweet}` == "true")
  {
    tweet_list.prepend(` <b>${payload.time}: ${payload.tweeter}: ${payload.org}'s RT:</b> ${payload.tweetText}<br>`);
  }
  tweet_list.prepend(btn);

  tweet_list.scrollTop;
});

channel.on('updatefeed', payload => {
  // alert("New tweet");
  console.log(payload);
  let tweet_list    = $('#tweet-list');
  var myTweets = payload.tweets;
  var arrayLength = myTweets.length;
  for (var i = 0; i < arrayLength; i++) {
    var btn = document.createElement("INPUT");
    btn.setAttribute('type', 'radio');
    btn.setAttribute('name', 'radioTweet');
    btn.setAttribute('user', `${payload.tweets[i].tweeter}`);
    btn.setAttribute('tweet', `${payload.tweets[i].tweetText}`);
    btn.setAttribute('tweetID', `${payload.tweets[i].tweetID}`);

    if(`${payload.tweets[i].isRetweet}` == "false")
    {
      tweet_list.prepend(` <b>${payload.tweets[i].time}: ${payload.tweets[i].tweeter}:</b> ${payload.tweets[i].tweetText}<br>`);
    }
    if(`${payload.tweets[i].isRetweet}` == "true")
    {
      tweet_list.prepend(` <b>${payload.tweets[i].time}: ${payload.tweets[i].tweeter}: ${payload.tweets[i].org}'s RT:</b> ${payload.tweets[i].tweetText}<br>`);
    }
    tweet_list.prepend(btn);
  }

  tweet_list.scrollTop;
});

if(document.getElementById("btnMyMentions"))         // use this if you are using id to check
{
  var userID =  getmyid();

  document.getElementById("btnMyMentions").onclick = function() {
  channel.push('getmentions', { username: userID });
};
}

if(document.getElementById("btnRetweet"))         // use this if you are using id to check
{
  document.getElementById("btnRetweet").onclick = function() {
    var userID =  getmyid();
    var val_radio = $('input[name=radioTweet]:checked').attr("tweet");
    var org_user = $('input[name=radioTweet]:checked').attr("user");
    var tweetid = $('input[name=radioTweet]:checked').attr("tweetID");
    channel.push('retweet', { username: userID,  tweet: val_radio, org: org_user, tweetID: tweetid});
}};

channel.on('getmentions', payload => {
  console.log(payload);
  var area   = document.getElementById("mentionsArea");
  var myTweets = payload.tweets;
  var arrayLength = myTweets.length;

  if (arrayLength == 0) {
    area.value = "I am not mentioned yet!";
  }
  else{
    area.innerHTML = '';
    for (var i = 0; i < arrayLength; i++) {
      area.innerHTML+=(` ${payload.tweets[i].time}: ${payload.tweets[i].tweeter}: ${payload.tweets[i].tweetText}`);
      area.innerHTML+="<br>";
    }
  }
  area.scrollTop;
  area.scrollLeft;
  // area.prop({scrollTop: area.prop("scrollHeight")});
});

if(document.getElementById("btnhashtag"))         // use this if you are using id to check
{
  let hash = document.querySelector('#hashtag');
  console.log(hash.value);
  document.getElementById("btnhashtag").onclick = function() {
    if(hash != ""){
      channel.push('gethashtag', {hashtag: hash.value });
    }
  };

  document.getElementById("hashtag")
    .addEventListener("keyup", function(event) {
    event.preventDefault();
    if (event.keyCode === 13) {
        document.getElementById("btnhashtag").click();
    }
  });

}

channel.on('gethashtag', payload => {
  var hasharea   = document.getElementById("hashtagArea");
  var tweets = payload.tweets;
  var arrayLength = tweets.length;
  console.log(arrayLength);

  if (arrayLength == 0) {
    hasharea.value = "No tweet with this hashtag!";
  }
  else{
    hasharea.innerHTML = '';
    for (var i = 0; i < arrayLength; i++) {
      hasharea.innerHTML+=(`${payload.tweets[i].tweeter}: ${payload.tweets[i].tweetText}`);
      hasharea.innerHTML+="<br>";
    }
  }
  hasharea.scrollTop;
  hasharea.scrollLeft;
});



channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
