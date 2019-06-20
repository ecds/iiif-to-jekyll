# Class representing the data we need from WebAnnotations fetched from Readux
class Annotation
  attr_accessor :x_px, :y_px, :w_px, :h_px, :motivation, :text, :user, :anno_id, :canvas

  module Motivation
    COMMENTING = "sc:commenting"
    PAINTING = "sc:painting"
  end

  # Sample source
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
       {"@type"=>"oa:FragmentSelector", "value"=>"xywh=1082,616,172,40"}}}

  # Sample output for OCR display in current system
  EXAMPLE_OCR_OUT=
    '<div class="ocr-line ocrtext" style="left:11.73%;top:64.23%;width:62.94%;height:2%;text-align:left;font-size:19.96px" data-vhfontsize="2">'+
    '  <span>Ad vnamquamque praterea Euangelicam leétionem fua</span>' +
    '</div>'


  def self.from_oa(json_hash, canvas)
    anno = Annotation.new
    anno.canvas = canvas
    anno.text = json_hash['resource']['chars']
    anno.anno_id = json_hash['@id']
    anno.motivation = json_hash['motivation']

    selector = json_hash['on']['selector']['value']
    md = selector.match /(\d+),(\d+),(\d+),(\d+)/
    anno.x_px = md[1].to_i
    anno.y_px = md[2].to_i
    anno.w_px = md[3].to_i
    anno.h_px = md[4].to_i

    anno
  end

  # TODO round these off to nearest hundredth
  def left_pct
    (100 * x_px.to_f / canvas.width).floor(2)
  end

  def top_pct
    (100 * y_px.to_f / canvas.height).floor(2)
  end

  def width_pct
    (100 * w_px.to_f / canvas.width).floor(2)
  end

  def height_pct
    (100 * h_px.to_f / canvas.height).floor(2)
  end

  # TODO determine font size (from what?)
  def font_size 
    "20px"  # this is specified in pixels, but surely that's wrong?
  end

  def self.all_annotations(annotation_list_json, canvas)
    annotations = []
    annotation_list_json['resources'].each do |anno_json|
      annotations << Annotation.from_oa(anno_json, canvas)
    end
    annotations
  end

  def self.ocr_annotations(annotation_list_json, canvas)
    annotations = all_annotations(annotation_list_json, canvas)
    annotations.keep_if { |anno| anno.motivation == Motivation::PAINTING }
  end

  def self.comment_annotations(annotation_list_json, canvas)
    annotations = all_annotations(annotation_list_json, canvas)
    annotations.keep_if { |anno| anno.motivation == Motivation::COMMENTING }
  end


end

