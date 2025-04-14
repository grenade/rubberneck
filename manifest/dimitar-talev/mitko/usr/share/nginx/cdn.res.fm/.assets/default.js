document.addEventListener('DOMContentLoaded', function(){
    if (window.location.pathname == '/') {
        document.querySelector('.parent-link').style.display = 'none';
    }
    const folders = window.location.pathname.split('/');
    const nav = document.querySelector("nav#breadcrumbs ul");
    let folderPath = '';
    for (let i = 1; i < folders.length - 1; i++) {
        folderPath += '/' + decodeURI(folders[i]);
        nav.innerHTML += '<li><a href="' + encodeURI(folderPath) + '">' + decodeURI(folders[i]) + '</a></li>';
    }
}, false);
