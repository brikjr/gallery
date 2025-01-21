(function( $ ){

	// fullscreen gallery
	var $fullscreen_gallery = jQuery('.fullscreen-gallery.gallery');
	if ( $fullscreen_gallery.length > 0 ) {

		if ( $fullscreen_gallery.find('.gallery-item').length > 1 ) { // if there are more than 1 image
			
			if ( !$fullscreen_gallery.hasClass('kenburns-gallery') ) {	// do not initialize if kenburns
				jQuery('#footer').prepend('<nav id="gallerynav"><a href="#" class="thumbs">	<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18">	<rect width="5" height="5" x="0"   y="0" /><rect width="5" height="5" x="8" y="0" /><rect width="5" height="5" x="0" y="8" /><rect width="5" height="5" x="8" y="8" /></svg></a><a href="#" class="prev">&lt;</a> <a href="#" class="pause">&#9614;&#9614;</a> <a href="#" class="next">&gt;</a></nav>');

				$fullscreen_gallery.before('<ul id="gallerythumbs">').cycle({
					slideExpr: '.gallery-item',
					fx:        'fade', 
		   			speed:     1000, 
					timeout:   5000,
					pager:   	 '#gallerythumbs', 
					slideResize: true,
					containerResize: true,
					width: '100%',
					height: '100%',
					fit: 1,
					cleartypeNoBg : true,
					pagerAnchorBuilder: function(idx, slide) { 
					   return '<li><a href="#"><img src="' + jQuery(slide).find('img').attr('src') + '" alt="" /></a></li>'; 
					},
					prev:    '#gallerynav .prev',
			  		next:    '#gallerynav .next'
				});
				var paused = false;
				jQuery('#gallerynav .pause').on('click', function() { 
					if ( !paused ) {
						$fullscreen_gallery.cycle('pause');
						paused = true;
					} 
					else {
						$fullscreen_gallery.cycle('resume'); 
						paused = false;
					}
					jQuery(this).toggleClass('active');
				});
				// show/hide thumbs
				var revealed = false;
				jQuery('#gallerynav a.thumbs').on('click', function() { 	// if clicked on svg button
					// show thumbs wrapper
					jQuery('#gallerythumbs').toggleClass('reveal');
					// show thumbs
					if (!revealed) {
						jQuery('body').addClass('gallerythumbsrevealed');
						revealed = true;
					}
					// hide thumbs
					else {
						jQuery('body').removeClass('gallerythumbsrevealed');
						revealed = false;
					}
					// pause cycling
					$fullscreen_gallery.cycle('pause');
					paused = true;
				});
				jQuery('#gallerythumbs').on('click', function() { // if clicked on a thumb (large image will be automatically shown) or somewhere else
					// hide thumbs wrapper
					jQuery('#gallerythumbs').toggleClass('reveal'); 
					jQuery('body').removeClass('gallerythumbsrevealed');
					// resume cycling
					$fullscreen_gallery.cycle('resume'); 
					paused = false;
					revealed = false;
				});
				// scroll gallery thumbs with mousewheel
				jQuery('#gallerythumbs').on('mousewheel', function(event) {
				    if (event.deltaY < 0) { // scroll right
						jQuery('#gallerythumbs').stop().animate({scrollLeft: '+=180px' }, 300); 
				    }
				    else {
						jQuery('#gallerythumbs').stop().animate({scrollLeft: '-=180px' }, 300); 
				    }
				});
			}
		}
	}



	// kenburns on one featured image header image
	var $kenburns = jQuery('.kenburns-gallery.gallery');

	if ($kenburns.length > 0) {
		var gallery_set = [];
		
		// Set up lazy loading for kenburns gallery images
		$kenburns.find('.gallery-icon img').each(function() {
			var $img = $(this);
			var imgSrc = $img.attr('src');
			gallery_set.push(imgSrc);
			
			// Create a low-res version of the image URL (assuming you have these)
			var lowResSrc = imgSrc.replace(/\.(png|jpe?g)$/i, '-thumb.$1');
			
			// Set up lazy loading attributes
			$img
				.attr('loading', 'lazy')
				.attr('data-src', imgSrc)
				.addClass('blur-load')
				.css({
					'background-image': `url(${lowResSrc})`,
					'background-size': 'cover',
					'min-height': '100vh'
				})
				.removeAttr('src');
		});

		// Function to check if the device is mobile
		function isMobile() {
			return window.matchMedia("(max-width: 767px)").matches;
		}

		// Initialize Intersection Observer for banner images
		var bannerObserver = new IntersectionObserver(function(entries, observer) {
			entries.forEach(function(entry) {
				if (entry.isIntersecting) {
					var img = entry.target;
					var $img = $(img);
					
					// Load the high-res image
					img.src = img.dataset.src;
					img.onload = function() {
						$img
							.addClass('is-loaded')
							.css('background-image', 'none');
					};
					observer.unobserve(img);
				}
			});
		}, {
			rootMargin: '50px 0px',
			threshold: 0.1
		});

		// Observe all banner images
		$kenburns.find('img').each(function() {
			bannerObserver.observe(this);
		});

		// Function to set up Ken Burns effect or static image
		function setupKenBurns() {
			var $container = jQuery('#kenburns');
			
			if (!isMobile()) {
				$container.empty();
				$container.attr('width', jQuery(window).width());
				$container.attr('height', jQuery(window).height());
				$container.kenburns({
					images: gallery_set,
					frames_per_second: 30,
					display_time: 5000,
					fade_time: 1000,
					zoom: 1,
					background_color: '#000'
				});
			} else {
				// Display static image for mobile
				var testImage = 'img/slider/snap.gif';
				if (gallery_set.length > 0) {
					$container.empty();
					var $firstImage = $container.css({
						'width': '80vh',
						'height': '110%',
						'margin-left': '-120px',
						'background-image': 'url(' + testImage + ')',
						'background-size': 'cover',
						'background-position': 'center center',
						'background-repeat': 'no-repeat',
						'z-index': -1
					});
				}
				$container.append($firstImage);
				$container.css('min-height', '300px');
			}
		}

		// Initial setup
		setupKenBurns();

		// Re-run on window resize
		jQuery(window).resize(function() {
			setupKenBurns();
		});
	}
	
	
	/* ********* WINDOW LOAD ********** */
	jQuery(window).load(function() {
	
		// load screen
		jQuery('.loadreveal').addClass('reveal');
		jQuery('#loadscreen').stop().animate( { opacity: 0 }, 200, function() {
			jQuery('body.home').removeClass('loading');
			jQuery(this).hide();
		});
	
	
		// masonry gallery
		var $masonry_gallery = jQuery('.masonry-gallery');
		if ($masonry_gallery.length > 0) {
			$masonry_gallery.each(function(index, element) {
				var $masonry_items = $(element).find('.gallery-item');
				var $grid = $(element);
				
				// Add loading class initially
				$masonry_gallery.addClass('is-loading');
				
				// Set up lazy loading attributes on images
				$grid.find('img').each(function() {
					var $img = $(this);
					$img
						.attr('loading', 'lazy')
						.attr('data-src', $img.attr('src'))
						.css('min-height', '200px') // Set initial height
						.removeAttr('src');
				});

				// Initialize Intersection Observer for lazy loading
				var imageObserver = new IntersectionObserver(function(entries, observer) {
					entries.forEach(function(entry) {
						if (entry.isIntersecting) {
							var img = entry.target;
							var $img = $(img);
							
							// Start loading the image
							img.src = img.dataset.src;
							
							// When image loads
							img.onload = function() {
								$img
									.addClass('is-loaded')
									.css('min-height', 'auto'); // Remove min-height after load
								$grid.isotope('layout');
							};
							
							observer.unobserve(img);
						}
					});
				}, {
					rootMargin: '50px 0px', // Start loading when image is 50px from viewport
					threshold: 0.1 // Trigger when even 10% of the image is visible
				});

				// Initialize isotope with initial layout
				$grid.isotope({
					itemSelector: '.gallery-item',
					percentPosition: true,
					masonry: {
						columnWidth: '.gallery-item'
					}
				});

				// Observe all images
				$grid.find('img').each(function() {
					imageObserver.observe(this);
				});

				// Remove loading class and show items once initial layout is done
				setTimeout(function() {
					$masonry_gallery.removeClass('is-loading');
					$('.gallery-item').addClass('is-visible');
				}, 500);

				// Keep your existing filtering code
				jQuery('#gallery-filter li a').on('click', function() {
					jQuery('#gallery-filter li a').removeClass('active');
					jQuery(this).addClass('active');
					var selector = jQuery(this).attr('data-filter');
					$grid.isotope({ filter: selector });
					return false;
				});

				// Keep your existing layout changing code
				jQuery('#grid-changer li a').on('click', function() {
					jQuery('#grid-changer li a').removeClass('active');
					jQuery(this).toggleClass('active');

					$masonry_items.removeClass('col-3');
					$masonry_items.removeClass('col-4');
					$masonry_items.removeClass('col-5');
					$masonry_items.toggleClass(jQuery(this).closest('li').attr('class'));
					$grid.isotope('layout');
				});
			});
		}

		
		// before-after
		var $before_after = jQuery('.before-after.gallery');
		if ( $before_after.length > 0 ) {
			$before_after.imageReveal({
				barWidth: 4,
				touchBarWidth: 50,
				startPosition: 0.5,
				width: jQuery('.before-after img').width(),
				height:  jQuery('.before-after img').height()
			});
		}

		// changing blog layout
		var $blog_layout = jQuery('#blog-timeline');
		if ( $blog_layout.length > 0 ) {
	
			jQuery('#grid-changer li a').on('click', function(){
				jQuery('#grid-changer li a').removeClass('active');
				jQuery(this).toggleClass('active');

				$blog_layout.closest('.wrapper').toggleClass('blog-masonry');
				
				if ( $blog_layout.closest('.wrapper').hasClass('blog-masonry') ) {
					jQuery('#blog-post').animate({'left': '100%'}, 400, function() {
						// set masonry layout
						$blog_layout.isotope({
							masonry: { columnWidth: $blog_layout.find('article')[0], gutter: 60 },
							itemSelector: 'article'
						});
						$blog_layout.isotope('layout');
						jQuery('#blog-post').hide();
					});
				}
				else {
					jQuery('#blog-post').show().animate({'left': '0'}, 400 );
					$blog_layout.isotope('destroy');
					
					if ( $masonry_gallery.length > 0 ) {
						$masonry_gallery.isotope('layout');
					}
				}
			});
		}
	});
	

	document.addEventListener('DOMContentLoaded', function() {
		// Find header container
		var headerContainer = document.querySelector('.intro-header');
		if (headerContainer) {
			// Get the background image URL
			var style = window.getComputedStyle(headerContainer);
			var bgImage = style.backgroundImage;
			
			if (bgImage && bgImage !== 'none') {
				// Create a new image to preload
				var img = new Image();
				img.onload = function() {
					headerContainer.classList.add('is-loaded');
				};
				// Extract URL from background-image property
				img.src = bgImage.replace(/url\(['"]?(.*?)['"]?\)/i, '$1');
			}
		}
	});

} )( jQuery );
