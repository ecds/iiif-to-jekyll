# Class representing the data we need from WebAnnotations fetched from Readux
# Attributes like `x_px` are data parsed from individual WebAnnotations
# Helper methods like `left_pct` translate raw data into derivative formats
# needed for Jekyll
# Static methods like `from_oa` or `ocr_annotations` parse WebAnnotation JSON
# hashes and AnnotationLists into usable collections of Annotation objects.
class Annotation
  attr_accessor :x_px, :y_px, :w_px, :h_px, :motivation, :text, :user, :anno_id, :canvas, :tags, :target_start, :target_end, :svg

  # Constants used for distinguishing OCR annotations from scholarly commentary
  module Motivation
    COMMENTING = 'oa:commenting'
    PAINTING = "sc:painting"
  end

  # Sample source annotation; for reference only
  EXAMPLE_OCR_SOURCE =
   {"@context"=>"http://iiif.io/api/presentation/2/context.json",
    "@id"=>"f87fef89-8176-4416-a7bb-ec0403016189",
    "@type"=>"oa:Annotation",
    "motivation"=>"sc:painting",
    "annotatedBy"=>{"name"=>"OCR"},
    "resource"=>
     {"@type"=>"cnt:ContentAsText",
      "format"=>"text/html",
      "chars"=>"Robert",
      "language"=>"en"},
    "on"=>
     {"full"=>
       "https://0.0.0.0:3000/iiif/v2/readux:t9pgf/canvas/14639457.24233.emory.edu$2",
      "@type"=>"oa:SpecificResource",
      "within"=>
       {"@id"=>"https://0.0.0.0:3000/iiif/v2/readux:t9pgf/manifest",
        "@type"=>"sc:Manifest"},
      "selector"=>
       {"@type"=>"oa:FragmentSelector", "value"=>"xywh=1082,616,172,40"}
     },
    "stylesheet" =>
      {
        "type" => "CssStylesheet",
        "value" => ".anno-f87fef89-8176-4416-a7bb-ec0403016189: { height: 59px; width: 619px; font-size: 36.875px; letter-spacing: 50.34027777777778px;}"
      }
    }

  # Sample output for OCR display in current system
  EXAMPLE_OCR_OUT=
    '<div class="ocr-line ocrtext"  data-vhfontsize="2">'+
    '  <span>Ad vnamquamque praterea Euangelicam leétionem fua</span>' +
    '</div>'

#this is what annotations of both types look like
            #     "resource": [
            #     {
            #         "@type": "dctypes:Text",
            #         "format": "text/html",
            #         "chars": "<p>A.S.M.</p>",
            #         "language": "en"
            #     },
            #     {
            #         "@type": "oa:Tag",
            #         "chars": "ben"
            #     }
            # ],


  # Factory method creating Annotation objects from hashes created by
  # parsing individual JSON WebAnnotations.
  def self.from_oa(json_hash, canvas)
    anno = Annotation.new

    # simple attributes
    anno.anno_id = json_hash['@id']
    anno.motivation = json_hash['motivation']
    anno.user = json_hash['annotatedBy']['name']

    if json_hash['resource'].kind_of? Array
      annotation_body = json_hash['resource'].detect { |e| e['@type'] == "dctypes:Text" }
      if annotation_body.nil?
        anno.text=""
      else
        anno.text = annotation_body['chars']
      end
      tag_bodies = json_hash['resource'].keep_if { |e| e['@type'] == "oa:Tag" }
      anno.tags = tag_bodies.map{|body| body["chars"]}
    else
      # ocr and comment-only annotations
      anno.text = json_hash['resource']['chars']
      anno.tags = []
    end


    # complex/parsed attributes
    selector = json_hash['on']['selector']['value']
    begin
      md = selector.match /(\d+),(\d+),(\d+),(\d+)/
      anno.x_px = md[1].to_i
      anno.y_px = md[2].to_i
      anno.w_px = md[3].to_i
      anno.h_px = md[4].to_i
      anno.canvas = canvas

      if json_hash["on"]["selector"]["item"]["@type"] == "oa:Choice"
        anno.svg = json_hash["on"]["selector"]["item"]["value"]
      else
        anno.svg=nil;
      end

      if json_hash['on']['selector']['item'] && json_hash['on']['selector']['item']['startSelector'] && json_hash['on']['selector']['item']['endSelector']
        raw_start = json_hash['on']['selector']['item']['startSelector']['value']
        anno.target_start = raw_start.sub("//*[@id='",'').sub("']","")
        raw_end = json_hash['on']['selector']['item']['endSelector']['value']
        anno.target_end = raw_end.sub("//*[@id='",'').sub("']","")
      end

      anno
    rescue NoMethodError
      nil
    end
  end

  def font_size
    h_px
  end

  # helper for line calculation
  def right_x
    x_px + w_px
  end

  # helper for line calculation
  def bottom_y
    y_px + h_px
  end


  Y_MARGIN_OF_ERROR = 10 # pixels considered probably the same line regardless
  # of skew, strange OCR, or bizarre printing

  # factory method for creating an arry of Annotation objectss from a raw hash
  # parsed from an AnnotationList
  def self.all_annotations(annotation_lists_json, canvas)
    annotations = []
    annotation_lists_json.each do |annotation_list|
      annotation_list['resources'].each do |anno_json|
        annotations << Annotation.from_oa(anno_json, canvas)
      end
    end

    annotations.compact!

    annotations.sort! do |a,b|
      if (a.y_px - b.y_px).abs < Y_MARGIN_OF_ERROR
        a.x_px <=> b.x_px
      else
        a.y_px <=> b.y_px
      end
    end

    annotations
  end

  # factory method parsing only OCR annotations
  def self.ocr_annotations(annotation_lists_json, canvas)
    annotations = all_annotations(annotation_lists_json, canvas)
    annotations.reject! { |anno| anno.motivation != Motivation::PAINTING }
    annotations || []
  end

  # factory method parsing only commentary annotations
  def self.comment_annotations(annotation_lists_json, canvas)
    annotations = all_annotations(annotation_lists_json, canvas)
    annotations.keep_if { |anno| anno.motivation == Motivation::COMMENTING || (anno.motivation.kind_of?(Array) && anno.motivation.include?(Motivation::COMMENTING)) }
    annotations || []
  end

  def self.all_tags
  end

  def self.image_comments(annotation_lists_json, canvas)
    annotations = comment_annotations(annotation_lists_json, canvas)
    annotations.keep_if { |anno| anno.target_start.nil?  }
    annotations
  end
end
