import Foundation
import WebKit

class ReaderModeService {
    
    // Enhanced content extraction script with Safari-like intelligence
    static let extractContentScript = """
    (function() {
        'use strict';
        
        // Performance optimization: Cache DOM queries
        const body = document.body;
        const head = document.head || document.getElementsByTagName('head')[0];
        
        // Quick check if already in reader mode
        if (document.getElementById('dumflow-reader-mode')) {
            return { success: false, reason: 'already_in_reader_mode' };
        }
        
        // Extract metadata (author, date, reading time)
        function extractMetadata() {
            const metadata = {
                author: null,
                publishDate: null,
                readingTime: null,
                siteName: null
            };
            
            // Try to extract author
            const authorSelectors = [
                'meta[name="author"]',
                'meta[property="article:author"]',
                '.author-name',
                '.by-author',
                '.article-author',
                '[rel="author"]',
                '.byline'
            ];
            
            for (const selector of authorSelectors) {
                const element = document.querySelector(selector);
                if (element) {
                    metadata.author = element.getAttribute('content') || element.textContent.trim();
                    if (metadata.author) break;
                }
            }
            
            // Try to extract publish date
            const dateSelectors = [
                'meta[property="article:published_time"]',
                'meta[name="publish_date"]',
                'time[datetime]',
                '.publish-date',
                '.article-date',
                '.post-date'
            ];
            
            for (const selector of dateSelectors) {
                const element = document.querySelector(selector);
                if (element) {
                    metadata.publishDate = element.getAttribute('content') || 
                                         element.getAttribute('datetime') || 
                                         element.textContent.trim();
                    if (metadata.publishDate) break;
                }
            }
            
            // Extract site name
            const siteElement = document.querySelector('meta[property="og:site_name"]') ||
                              document.querySelector('meta[name="application-name"]');
            if (siteElement) {
                metadata.siteName = siteElement.getAttribute('content');
            }
            
            return metadata;
        }
        
        // Calculate reading time
        function calculateReadingTime(text) {
            const wordsPerMinute = 200;
            const wordCount = text.trim().split(/\\s+/).length;
            const minutes = Math.ceil(wordCount / wordsPerMinute);
            return minutes;
        }
        
        // Enhanced content scoring algorithm
        function scoreElement(element) {
            let score = 0;
            const text = element.textContent || '';
            const className = element.className.toLowerCase();
            const id = element.id.toLowerCase();
            
            // Positive signals
            score += text.length / 100;
            score += (text.split('. ').length - 1) * 3;
            score += element.querySelectorAll('p').length * 5;
            score += element.querySelectorAll('h2, h3, h4').length * 3;
            
            // Strong positive indicators
            if (element.tagName === 'ARTICLE') score += 30;
            if (className.includes('article') || className.includes('content')) score += 20;
            if (id.includes('article') || id.includes('content')) score += 20;
            
            // Check for article-like structure
            const paragraphs = element.querySelectorAll('p');
            const avgParagraphLength = Array.from(paragraphs)
                .reduce((sum, p) => sum + p.textContent.length, 0) / (paragraphs.length || 1);
            if (avgParagraphLength > 100) score += 10;
            
            // Negative signals
            if (className.includes('comment') || className.includes('sidebar')) score -= 50;
            if (className.includes('nav') || className.includes('menu')) score -= 40;
            if (className.includes('footer') || className.includes('header')) score -= 40;
            if (className.includes('ad') || className.includes('promo')) score -= 100;
            
            // Check link density (too many links = probably navigation)
            const linkDensity = element.querySelectorAll('a').length / (text.length / 100);
            if (linkDensity > 1) score -= linkDensity * 10;
            
            return score;
        }
        
        // Fast content extraction using multiple strategies
        function extractMainContent() {
            let content = null;
            let title = document.title || '';
            
            // Try to get better title from og:title or h1
            const ogTitle = document.querySelector('meta[property="og:title"]');
            if (ogTitle) {
                title = ogTitle.getAttribute('content') || title;
            } else {
                const h1 = document.querySelector('h1');
                if (h1 && h1.textContent.trim().length > 10) {
                    title = h1.textContent.trim();
                }
            }
            
            // Strategy 1: Look for semantic article containers
            const articleElement = document.querySelector('article');
            if (articleElement && articleElement.textContent.length > 300) {
                content = articleElement;
            }
            
            // Strategy 2: Score-based extraction
            if (!content) {
                const candidates = [];
                const containers = document.querySelectorAll('div, section, main, article');
                
                containers.forEach(container => {
                    // Skip if too small
                    if (container.textContent.length < 200) return;
                    
                    const score = scoreElement(container);
                    if (score > 0) {
                        candidates.push({ element: container, score });
                    }
                });
                
                // Sort by score and get best
                candidates.sort((a, b) => b.score - a.score);
                if (candidates.length > 0) {
                    content = candidates[0].element;
                }
            }
            
            // Strategy 3: Find content by common patterns
            if (!content) {
                const contentSelectors = [
                    '.post-content',
                    '.article-content',
                    '.entry-content',
                    '.content-body',
                    '[itemprop="articleBody"]',
                    '.story-body',
                    '#article-body',
                    '.article-text'
                ];
                
                for (const selector of contentSelectors) {
                    const element = document.querySelector(selector);
                    if (element && element.textContent.length > 200) {
                        content = element;
                        break;
                    }
                }
            }
            
            return { content, title };
        }
        
        function cleanContent(element, keepImages = true) {
            if (!element) return '';
            
            const clone = element.cloneNode(true);
            
            // Remove unwanted elements
            const unwantedSelectors = [
                'script', 'style', 'nav', 'header', 'footer', 'aside',
                '.ad', '.advertisement', '.social-share', '.comments',
                '.related-articles', '.sidebar', '[data-ad]',
                'iframe[src*="ad"]', '.promo', '.newsletter',
                '.share-buttons', '.social-media', '.subscribe',
                '.popup', '.modal', '.banner', '[class*="recommended"]',
                '[class*="related"]', '[class*="popular"]'
            ];
            
            unwantedSelectors.forEach(selector => {
                clone.querySelectorAll(selector).forEach(el => el.remove());
            });
            
            // Handle images intelligently
            if (keepImages) {
                // Remove decorative/ad images
                clone.querySelectorAll('img').forEach(img => {
                    const src = img.src || '';
                    const alt = img.alt || '';
                    const width = parseInt(img.getAttribute('width') || '0');
                    const height = parseInt(img.getAttribute('height') || '0');
                    
                    // Remove if likely an ad or tracking pixel
                    if (src.includes('doubleclick') || 
                        src.includes('amazon-adsystem') ||
                        src.includes('googleadservices') ||
                        (width < 50 && height < 50) ||
                        src.includes('pixel') ||
                        src.includes('tracking')) {
                        img.remove();
                        return;
                    }
                    
                    // Remove if decorative (no alt text and small)
                    if (!alt && width < 200 && height < 200) {
                        img.remove();
                        return;
                    }
                    
                    // Clean up image attributes
                    img.removeAttribute('onclick');
                    img.removeAttribute('onload');
                    img.removeAttribute('onerror');
                });
            } else {
                // Remove all images if requested
                clone.querySelectorAll('img, picture, figure').forEach(el => el.remove());
            }
            
            // Clean up attributes
            clone.querySelectorAll('*').forEach(el => {
                // Keep semantic attributes
                const keepAttrs = ['href', 'src', 'alt', 'title', 'datetime', 'cite'];
                const attrs = Array.from(el.attributes);
                attrs.forEach(attr => {
                    if (!keepAttrs.includes(attr.name)) {
                        el.removeAttribute(attr.name);
                    }
                });
                
                // Remove onclick handlers
                if (el.hasAttribute('onclick')) {
                    el.removeAttribute('onclick');
                }
            });
            
            // Remove empty elements
            clone.querySelectorAll('p, div, span').forEach(el => {
                if (!el.textContent.trim() && !el.querySelector('img')) {
                    el.remove();
                }
            });
            
            return clone.innerHTML;
        }
        
        // Extract content
        const { content, title } = extractMainContent();
        
        if (!content) {
            return { success: false, reason: 'no_content_found' };
        }
        
        const cleanedContent = cleanContent(content, true);
        const metadata = extractMetadata();
        const readingTime = calculateReadingTime(content.textContent || '');
        
        if (cleanedContent.length < 100) {
            return { success: false, reason: 'content_too_short' };
        }
        
        return {
            success: true,
            title: title,
            content: cleanedContent,
            metadata: {
                ...metadata,
                readingTime: readingTime
            },
            originalUrl: window.location.href
        };
    })();
    """
    
    // Generate CSS styles based on reader settings
    static func generateReaderCSS(settings: ReaderModeSettings) -> String {
        return """
        /* Reader Mode Styles - Safari-inspired Design */
        #dumflow-reader-mode {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: 100vw !important;
            height: 100vh !important;
            background: \(settings.backgroundColor.cssValue) !important;
            z-index: 999999 !important;
            overflow-y: auto !important;
            -webkit-overflow-scrolling: touch !important;
            font-feature-settings: "kern" 1 !important;
            text-rendering: optimizeLegibility !important;
        }
        
        #dumflow-reader-content {
            max-width: \(settings.contentWidth.cssValue) !important;
            margin: 0 auto !important;
            padding: 80px 20px 60px !important;
            font-family: \(settings.fontFamily.cssValue) !important;
            font-size: \(settings.fontSize.cssValue) !important;
            line-height: \(settings.lineHeight.cssValue) !important;
            color: \(settings.textColor.cssValue) !important;
            background: transparent !important;
        }
        
        /* Metadata section */
        #dumflow-reader-metadata {
            margin-bottom: 2em !important;
            padding-bottom: 1em !important;
            border-bottom: 1px solid rgba(128, 128, 128, 0.2) !important;
            font-size: 0.9em !important;
            color: \(settings.textColor.cssValue) !important;
            opacity: 0.7 !important;
        }
        
        #dumflow-reader-metadata .site-name {
            font-weight: 600 !important;
            text-transform: uppercase !important;
            letter-spacing: 0.05em !important;
            font-size: 0.85em !important;
        }
        
        #dumflow-reader-metadata .author-date {
            margin-top: 0.5em !important;
        }
        
        #dumflow-reader-metadata .reading-time {
            margin-top: 0.5em !important;
            font-style: italic !important;
        }
        
        /* Typography */
        #dumflow-reader-content h1,
        #dumflow-reader-content h2,
        #dumflow-reader-content h3,
        #dumflow-reader-content h4,
        #dumflow-reader-content h5,
        #dumflow-reader-content h6 {
            color: \(settings.textColor.cssValue) !important;
            font-family: \(settings.fontFamily.cssValue) !important;
            font-weight: 700 !important;
            margin: 1.5em 0 0.5em !important;
            line-height: 1.2 !important;
            letter-spacing: -0.02em !important;
        }
        
        #dumflow-reader-content h1 { 
            font-size: 2em !important;
            margin-top: 0 !important;
            margin-bottom: 0.8em !important;
        }
        #dumflow-reader-content h2 { font-size: 1.5em !important; }
        #dumflow-reader-content h3 { font-size: 1.3em !important; }
        
        #dumflow-reader-content p {
            margin: 0 0 1.5em !important;
            color: \(settings.textColor.cssValue) !important;
            font-family: \(settings.fontFamily.cssValue) !important;
            orphans: 3 !important;
            widows: 3 !important;
        }
        
        /* First paragraph - larger text */
        #dumflow-reader-content > p:first-of-type {
            font-size: 1.15em !important;
            line-height: 1.5 !important;
            font-weight: 400 !important;
        }
        
        /* Drop cap for first letter */
        #dumflow-reader-content > p:first-of-type::first-letter {
            float: left !important;
            font-size: 3.5em !important;
            line-height: 1 !important;
            font-weight: 700 !important;
            margin: 0 0.1em 0 0 !important;
            color: \(settings.textColor.cssValue) !important;
        }
        
        #dumflow-reader-content img {
            max-width: 100% !important;
            height: auto !important;
            margin: 2em auto !important;
            display: block !important;
            border-radius: 8px !important;
            box-shadow: 0 1px 4px rgba(0, 0, 0, 0.1) !important;
        }
        
        #dumflow-reader-content a {
            color: #007AFF !important;
            text-decoration: none !important;
            border-bottom: 1px solid rgba(0, 122, 255, 0.3) !important;
            transition: border-color 0.2s ease !important;
        }
        
        #dumflow-reader-content a:hover {
            border-bottom-color: #007AFF !important;
        }
        
        #dumflow-reader-content blockquote {
            border-left: 4px solid rgba(0, 122, 255, 0.5) !important;
            padding-left: 1.5em !important;
            margin: 2em 0 !important;
            font-style: italic !important;
            color: \(settings.textColor.cssValue) !important;
            opacity: 0.85 !important;
        }
        
        #dumflow-reader-content pre,
        #dumflow-reader-content code {
            font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace !important;
            background: rgba(128, 128, 128, 0.1) !important;
            padding: 0.2em 0.4em !important;
            border-radius: 4px !important;
            font-size: 0.9em !important;
        }
        
        #dumflow-reader-content pre {
            padding: 1.5em !important;
            overflow-x: auto !important;
            margin: 2em 0 !important;
            line-height: 1.4 !important;
        }
        
        #dumflow-reader-content ul,
        #dumflow-reader-content ol {
            margin: 1.5em 0 !important;
            padding-left: 2em !important;
        }
        
        #dumflow-reader-content li {
            margin: 0.5em 0 !important;
            line-height: \(settings.lineHeight.cssValue) !important;
        }
        
        #dumflow-reader-content hr {
            border: none !important;
            height: 1px !important;
            background: rgba(128, 128, 128, 0.2) !important;
            margin: 3em 0 !important;
        }
        
        /* Table styling */
        #dumflow-reader-content table {
            border-collapse: collapse !important;
            width: 100% !important;
            margin: 2em 0 !important;
        }
        
        #dumflow-reader-content th,
        #dumflow-reader-content td {
            border: 1px solid rgba(128, 128, 128, 0.2) !important;
            padding: 0.75em !important;
            text-align: left !important;
        }
        
        #dumflow-reader-content th {
            font-weight: 600 !important;
            background: rgba(128, 128, 128, 0.05) !important;
        }
        
        /* Hide original content when reader mode is active */
        body.dumflow-reader-active > *:not(#dumflow-reader-mode) {
            display: none !important;
        }
        
        /* Ensure reader mode is always on top */
        body.dumflow-reader-active {
            overflow: hidden !important;
        }
        
        /* Smooth transitions */
        #dumflow-reader-mode {
            animation: dumflowFadeIn 0.3s ease-out !important;
        }
        
        @keyframes dumflowFadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        /* Image toggle button */
        #dumflow-image-toggle {
            position: fixed !important;
            top: 20px !important;
            right: 20px !important;
            background: rgba(0, 122, 255, 0.1) !important;
            border: 1px solid #007AFF !important;
            border-radius: 8px !important;
            padding: 8px 16px !important;
            color: #007AFF !important;
            font-size: 14px !important;
            cursor: pointer !important;
            z-index: 1000000 !important;
            transition: all 0.2s ease !important;
        }
        
        #dumflow-image-toggle:hover {
            background: #007AFF !important;
            color: white !important;
        }
        
        /* When images are hidden */
        .dumflow-hide-images img {
            display: none !important;
        }
        """
    }
    
    // Apply reader mode with optimized performance
    static func applyReaderModeScript(settings: ReaderModeSettings) -> String {
        let css = generateReaderCSS(settings: settings)
        
        return """
        (function() {
            'use strict';
            
            // Check if already applied
            if (document.getElementById('dumflow-reader-mode')) {
                return { success: true, message: 'already_applied' };
            }
            
            // Get the extracted content from previous extraction
            const contentData = window.dumflowExtractedContent;
            if (!contentData || !contentData.success) {
                return { success: false, reason: 'no_extracted_content' };
            }
            
            // Create reader mode container
            const readerContainer = document.createElement('div');
            readerContainer.id = 'dumflow-reader-mode';
            
            // Create content container
            const contentContainer = document.createElement('div');
            contentContainer.id = 'dumflow-reader-content';
            
            // Add metadata section if available
            let metadataHTML = '';
            if (contentData.metadata) {
                const meta = contentData.metadata;
                metadataHTML = '<div id="dumflow-reader-metadata">';
                
                if (meta.siteName) {
                    metadataHTML += `<div class="site-name">${meta.siteName}</div>`;
                }
                
                let authorDateLine = '';
                if (meta.author) {
                    authorDateLine += `By ${meta.author}`;
                }
                if (meta.publishDate) {
                    if (authorDateLine) authorDateLine += ' • ';
                    // Format date nicely
                    try {
                        const date = new Date(meta.publishDate);
                        const options = { year: 'numeric', month: 'long', day: 'numeric' };
                        authorDateLine += date.toLocaleDateString('en-US', options);
                    } catch (e) {
                        authorDateLine += meta.publishDate;
                    }
                }
                if (authorDateLine) {
                    metadataHTML += `<div class="author-date">${authorDateLine}</div>`;
                }
                
                if (meta.readingTime) {
                    metadataHTML += `<div class="reading-time">${meta.readingTime} min read</div>`;
                }
                
                metadataHTML += '</div>';
            }
            
            // Add title if available
            let titleHTML = '';
            if (contentData.title) {
                titleHTML = `<h1>${contentData.title}</h1>`;
            }
            
            // Set content
            contentContainer.innerHTML = metadataHTML + titleHTML + contentData.content;
            
            // Add to reader container
            readerContainer.appendChild(contentContainer);
            
            // Add image toggle button
            const imageToggle = document.createElement('button');
            imageToggle.id = 'dumflow-image-toggle';
            imageToggle.textContent = 'Hide Images';
            imageToggle.onclick = function() {
                contentContainer.classList.toggle('dumflow-hide-images');
                this.textContent = contentContainer.classList.contains('dumflow-hide-images') 
                    ? 'Show Images' : 'Hide Images';
            };
            readerContainer.appendChild(imageToggle);
            
            // Add CSS styles
            const style = document.createElement('style');
            style.textContent = `\(css)`;
            document.head.appendChild(style);
            
            // Add reader mode to body
            document.body.appendChild(readerContainer);
            document.body.classList.add('dumflow-reader-active');
            
            // Scroll to top
            readerContainer.scrollTop = 0;
            
            // Focus for keyboard navigation
            readerContainer.focus();
            
            return { success: true, message: 'reader_mode_applied' };
        })();
        """
    }
    
    // Exit reader mode script
    static let exitReaderModeScript = """
    (function() {
        'use strict';
        
        const readerMode = document.getElementById('dumflow-reader-mode');
        if (readerMode) {
            // Smooth exit animation
            readerMode.style.animation = 'dumflowFadeOut 0.3s ease-out';
            
            setTimeout(() => {
                readerMode.remove();
                document.body.classList.remove('dumflow-reader-active');
                
                // Remove reader mode styles
                const readerStyles = document.querySelectorAll('style');
                readerStyles.forEach(style => {
                    if (style.textContent.includes('dumflow-reader-mode')) {
                        style.remove();
                    }
                });
            }, 300);
            
            return { success: true, message: 'reader_mode_exited' };
        }
        
        return { success: false, reason: 'reader_mode_not_active' };
    })();
    
    /* Add exit animation */
    if (!document.querySelector('style[data-dumflow-exit]')) {
        const exitStyle = document.createElement('style');
        exitStyle.setAttribute('data-dumflow-exit', 'true');
        exitStyle.textContent = `
            @keyframes dumflowFadeOut {
                from { opacity: 1; transform: translateY(0); }
                to { opacity: 0; transform: translateY(-20px); }
            }
        `;
        document.head.appendChild(exitStyle);
    }
    """
    
    // Check if reader mode is currently active
    static let isReaderModeActiveScript = """
    (function() {
        return document.getElementById('dumflow-reader-mode') !== null;
    })();
    """
    
    // Store extracted content for later use
    static let storeExtractedContentScript = """
    (function(contentData) {
        window.dumflowExtractedContent = contentData;
        return { success: true };
    })
    """
}