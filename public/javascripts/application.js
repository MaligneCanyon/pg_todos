$(function() {

  // since form submission is triggered by a button click, could use the following ...
  // <button type="submit" class="delete">Delete List</button>
  // $('button.delete').on('click', function() {
  //   confirm('Are you sure ? This action cannot be undone!'); // prompt to confirm deletion
  // });

  // submit method takes an event handler as an arg, a fn which looks for a specific event
  // to have been triggered (in this case, the form being submitted)
  $('form.delete').submit(function(event) {
    event.preventDefault(); // prevent default behaviour
    event.stopPropagation(); // stop the event from affecting another part of the page or the browser itself

    var ok = confirm('Are you sure? This cannot be undone!'); // prompt to confirm deletion
    if (ok) {
      // this.submit(); // submit the form

      var form = $(this); // save a ref to the form obj

      // send an async req to the server to del the list item
      // save the jQuery obj rtn'd by the .ajax method
      var request = $.ajax({
        url: form.attr("action"),
        method: form.attr("method")
      });

      // setup a .done callback that fires whenever the req completes successfully
      request.done(function(data, textStatus, jqXHR) {
        if (jqXHR.status == 204) { // should use === for comparison of same data type
          form.parent("li").remove(); // remove a todo item
        } else if (jqXHR.status == 200) { // should use === for comparison of same data type
          // tell the browser to go to a new URL
          // the URL is the rtn value "/lists" from the 'post "/lists/:list_ndx/delete"' route
          // the URL is stored in the 'data' arg
          document.location = data;
        }
      });
    }
  });

});
