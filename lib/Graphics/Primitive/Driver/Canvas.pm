package Graphics::Primitive::Driver::Canvas;
use Moose;
use Moose::Util::TypeConstraints;

use Carp;
use Geometry::Primitive::Point;
use Geometry::Primitive::Rectangle;
# use Graphics::Primitive::Driver::Canvas::TextLayout;
use IO::File;
use Math::Trig ':pi';

with 'Graphics::Primitive::Driver';

our $AUTHORITY = 'cpan:GPHAT';
our $VERSION = '0.42';

# If we encounter an operation with 'preserve' set to true we'll set this attr
# to the number of primitives in that path.  On each iteration we'll check
# this attribute.  If it's true, we'll skip that many primitives in the
# current path and then reset the value.  This allows us to leverage cairo's
# fill_preserve and stroke_perserve and avoid wasting time redrawing.
has '_preserve_count' => (
    isa => 'Str',
    is  => 'rw',
    default => sub { 0 }
);

has 'js' => (
    traits => [ 'String' ],
    isa => 'Str',
    is => 'rw',
    default => "function draw() {\nvar canvas = document.getElementById(\"canvas\");\nvar ctx = canvas.getContext(\"2d\");\n",
    handles => {
        add_js => 'append'
    }
);

sub data {
    my ($self) = @_;

    return $self->js."}\n";
}

around('draw', sub {
    my ($cont, $class, $comp) = @_;

    # $class->add_js("ctx.save();\n");
    $class->add_js("ctx.translate(".$comp->origin->to_string.");\n");
    my ($mt, $mr, $mb, $ml) = $comp->margins->as_array;
    $class->add_js("ctx.rect($mr, $mt, ".($comp->width - $mr - $ml).",".($comp->height - $mt - $mb).");\n");
    $class->add_js("ctx.clip();\n");
    # $class->add_js("ctx.restore();\n");

    $cont->($class, $comp);
});

sub write {
    my ($self, $file) = @_;

    my $fh = IO::File->new($file, 'w')
        or die("Unable to open '$file' for writing: $!");
    $fh->print($self->data);
    $fh->close;
}

sub set_style {
    my ($self, $brush, $color) = @_;

    unless(defined($color)) {
        $color = $brush->color;
    }
    $self->add_js("\n\n");
    $self->add_js("ctx.fillStyle = \"rgba(".$color->as_integer_string.");\"\n");
    $self->add_js("ctx.strokeStyle = \"rgba(".$color->as_integer_string.");\"\n");
    if(defined($brush)) {
        $self->add_js("ctx.lineWidth = ".$brush->width.";\n");
        $self->add_js("ctx.lineCap = '".$brush->line_cap."';\n");
        $self->add_js("ctx.lineJoin = '".$brush->line_join."';\n");
    }
}

sub _draw_component {
    my ($self, $comp) = @_;

    if(defined($comp->background_color)) {
        $self->add_js("ctx.fillStyle = \"rgba(".$comp->background_color->as_integer_string.");\"\n");
        $self->add_js("ctx.beginPath();\n");
        my ($mt, $mr, $mb, $ml) = $comp->margins->as_array;
        $self->add_js("ctx.fillRect($mr,$mt,".$comp->width.",".$comp->height.");\n");
    }

    if(defined($comp->border)) {

        my $border = $comp->border;

        if($border->homogeneous) {
            # Don't bother if there's no width
            if($border->top->width) {
                $self->_draw_simple_border($comp);
            }
        } else {
            $self->_draw_complex_border($comp);
        }
    }
}

sub _draw_complex_border {
    my ($self, $comp) = @_;

    my ($mt, $mr, $mb, $ml) = $comp->margins->as_array;

    my $border = $comp->border;

    my $width = $comp->width;
    my $height = $comp->height;

    my $bt = $border->top;
    my $thalf = (defined($bt) && defined($bt->color))
        ? $bt->width / 2: 0;

    my $br = $border->right;
    my $rhalf = (defined($br) && defined($br->color))
        ? $br->width / 2: 0;

    my $bb = $border->bottom;
    my $bhalf = (defined($bb) && defined($bb->color))
        ? $bb->width / 2 : 0;

    my $bl = $border->left;
    my $lhalf = (defined($bl) && defined($bl->color))
        ? $bl->width / 2 : 0;

    if($thalf) {
        $self->set_style($br);
        $self->add_js("// Begin Top Border\n");
        $self->add_js("ctx.beginPath();\n");
        my $y = $mt + $thalf;
        $self->set_style($bt);
        $self->add_js("ctx.moveTo($ml,$y);\n");
        $self->add_js("ctx.lineTo($width, $y);\n");

        my $dash = $bt->dash_pattern;
        if(defined($dash) && scalar(@{ $dash })) {
            # $context->set_dash(0, @{ $dash });
        }


        $self->add_js("ctx.stroke();\n");
        $self->add_js("// End Top Border\n");
        # $context->stroke;

        # $context->set_dash(0, []);
    }

    if($rhalf) {
        $self->set_style($br);
        $self->add_js("// Begin Right Border\n");
        $self->add_js("ctx.beginPath();\n");
        my $x = $width - $mr - $rhalf;
        # $context->move_to($width - $mr - $rhalf, $mt);
        $self->add_js("ctx.moveTo($x,$mt);\n");
        # $context->set_source_rgba($br->color->as_array_with_alpha);

        # $context->set_line_width($br->width);
        # $context->rel_line_to(0, $height - $mb);
        my $y = $height - $mb;
        $self->add_js("ctx.lineTo($x,$y);\n");

        my $dash = $br->dash_pattern;
        if(defined($dash) && scalar(@{ $dash })) {
            # $context->set_dash(0, @{ $dash });
        }

        # $context->stroke;
        $self->add_js("ctx.stroke();\n");
        $self->add_js("// End Right Border\n");
        # $context->set_dash(0, []);
    }

    if($bhalf) {
        $self->set_style($bb);
        $self->add_js("//Begin Bottom Border\n");
        $self->add_js("ctx.beginPath();\n");
        my $y = $height - $mb - $bhalf;
        $self->add_js("ctx.moveTo($mr,$y);\n");
        # $context->move_to($width - $mr, $height - $bhalf - $mb);
        # $context->set_source_rgba($bb->color->as_array_with_alpha);

        # $context->set_line_width($bb->width);
        # $context->rel_line_to(-($width - $mb), 0);
        my $x = $width - $mr;
        $self->add_js("ctx.lineTo($x,$y);\n");

        my $dash = $bb->dash_pattern;
        if(defined($dash) && scalar(@{ $dash })) {
            # $context->set_dash(0, @{ $dash });
        }

        # $context->stroke;
        $self->add_js("ctx.stroke();\n");
        $self->add_js("// End Bottom Border\n");
    }

    if($lhalf) {
        $self->set_style($bl);
        $self->add_js("//Begin Bottom Border\n");
        $self->add_js("ctx.beginPath();\n");

        my $x = $ml + $lhalf;
        $self->add_js("ctx.moveTo($x, $mt);\n");
        # $context->move_to($ml + $lhalf, $mt);
        # $context->set_source_rgba($bl->color->as_array_with_alpha);

        my $y = $height - $mb;
        $self->add_js("ctx.lineTo($x, $y);\n");
        # $context->set_line_width($bl->width);
        # $context->rel_line_to(0, $height - $mb);

        my $dash = $bl->dash_pattern;
        if(defined($dash) && scalar(@{ $dash })) {
            # $context->set_dash(0, @{ $dash });
        }

        # $context->stroke;
        # $context->set_dash(0, []);

        $self->add_js("ctx.stroke();\n");
        $self->add_js("// End Left Border\n");
    }
}

sub _draw_simple_border {
    my ($self, $comp) = @_;

    my $border = $comp->border;
    my $top = $border->top;
    my $bswidth = $top->width;

    my @margins = $comp->margins->as_array;

    $self->set_style($top);

    my $swhalf = $bswidth / 2;
    my $width = $comp->width;
    my $height = $comp->height;

    # my $dash = $top->dash_pattern;
    # if(defined($dash) && scalar(@{ $dash })) {
    #     $context->set_dash(0, @{ $dash });
    # }

    my $x = $margins[3] + $swhalf;
    my $y = $margins[0] + $swhalf;
    my $w = $comp->inside_width + $bswidth;
    my $h = $comp->inside_height + $bswidth;

    $self->add_js("// Begin Simple Border\n");
    $self->add_js("ctx.beginPath();\n");
    $self->add_js("ctx.rect($x,$y,$w,$h);\n");
    $self->add_js("ctx.stroke();\n");
    $self->add_js("// End Simple Border\n\n");

    # Reset dashing
    # $context->set_dash(0, []);
}

sub _draw_textbox {
    my ($self, $comp) = @_;

    return unless defined($comp->text);

    $self->_draw_component($comp);

    my $bbox = $comp->inside_bounding_box;

    my $height = $bbox->height;
    my $height2 = $height / 2;
    my $width = $bbox->width;
    my $width2 = $width / 2;

    my $halign = $comp->horizontal_alignment;
    my $valign = $comp->vertical_alignment;

    my $context = $self->cairo;

    my $font = $comp->font;
    my $fsize = $font->size;
    $context->select_font_face(
        $font->face, $font->slant, $font->weight
    );
    $context->set_font_size($fsize);

    my $options = Cairo::FontOptions->create;
    $options->set_antialias($font->antialias_mode);
    $options->set_subpixel_order($font->subpixel_order);
    $options->set_hint_style($font->hint_style);
    $options->set_hint_metrics($font->hint_metrics);
    $context->set_font_options($options);

    my $angle = $comp->angle;

    $context->set_source_rgba($comp->color->as_array_with_alpha);

    my $lh = $comp->line_height;
    $lh = $fsize unless(defined($lh));

    my $yaccum = $bbox->origin->y;

    foreach my $line (@{ $comp->layout->lines }) {
        my $text = $line->{text};
        my $tbox = $line->{box};

        my $o = $tbox->origin;
        my $bbo = $bbox->origin;
        my $twidth = $tbox->width;
        my $theight = $tbox->height;

        my $x = $bbox->origin->x + $o->x;

        my $ydiff = $theight + $o->y;
        my $xdiff = $twidth + $o->x;

        my $realh = $theight + $ydiff;
        my $realw = $twidth + $xdiff;
        my $theight2 = $realh / 2;
        my $twidth2 = $twidth / 2;

        my $y = $yaccum + $theight;

        $context->save;

        if($angle) {
            my $twidth2 = $twidth / 2;
            my $cwidth2 = $width / 2;
            my $cheight2 = $height / 2;

            $context->translate($cwidth2, $cheight2);
            $context->rotate($angle);
            $context->translate(-$cwidth2, -$cheight2);

            $context->move_to($cwidth2 - $twidth2, $cheight2 + $theight / 3.5);
            $context->show_text($text);

        } else {
            if($halign eq 'right') {
                $x += $width - $twidth;
            } elsif($halign eq 'center') {
                $x += $width2 - $twidth2;
            }

            if($valign eq 'bottom') {
                $y = $height - $ydiff;
            } elsif($valign eq 'center') {
                $y += $height2 - $theight2;
            } else {
                $y -= $ydiff;
            }

            $context->move_to($x, $y);
            $context->show_text($text);
        }

        $context->restore;
        $yaccum += $lh;
    }

}

sub _draw_arc {
    my ($self, $arc) = @_;

    $self->add_js("// Begin Arc\n");
    my $o = $arc->origin;
    if($arc->angle_start > $arc->angle_end) {
        $self->add_js("ctx.arc(".$o->x.",".$o->y.",".$arc->radius.",".$arc->angle_start.",".$arc->angle_end.",true);\n");
    } else {
        $self->add_js("ctx.arc(".$o->x.",".$o->y.",".$arc->radius.",".$arc->angle_start.",".$arc->angle_end.",false);\n");
    }
    $self->add_js("// End Arc\n");
}

sub _draw_bezier {
    my ($self, $bezier) = @_;

    my $context = $self->cairo;
    my $start = $bezier->start;
    my $end = $bezier->end;
    my $c1 = $bezier->control1;
    my $c2 = $bezier->control2;

    $context->curve_to($c1->x, $c1->y, $c2->x, $c2->y, $end->x, $end->y);
}

sub _draw_canvas {
    my ($self, $comp) = @_;

    $self->_draw_component($comp);

    foreach (@{ $comp->paths }) {

        $self->_draw_path($_->{path}, $_->{op});
    }
}

sub _draw_circle {
    my ($self, $circle) = @_;

    my $context = $self->cairo;
    my $o = $circle->origin;
    $context->new_sub_path;
    $context->arc(
        $o->x, $o->y, $circle->radius, 0, pi2
    );
}

sub _draw_ellipse {
    my ($self, $ell) = @_;

    my $o = $ell->origin;

    $self->add_js("// Begin Ellipse\n");
    # $self->add_js("ctx.beginPath();\n");
    $self->add_js("ctx.save();\n");
    $self->add_js("ctx.translate(".$o->x.",".$o->y.");\n");
    # $cairo->new_sub_path;
    # $cairo->save;
    # $cairo->translate($o->x, $o->y);
    $self->add_js("ctx.scale(".($ell->width / 2).",".($ell->height / 2).");\n");
    # $cairo->scale($ell->width / 2, $ell->height / 2);
    $self->add_js("ctx.arc(".$o->x.",".$o->y.",1,2,".pi2.",false);\n");
    # $cairo->arc(
    #     $o->x, $o->y, 1, 0, pi2
    # );
    $self->add_js("ctx.restore();\n");
    $self->add_js("// End Ellipse\n");
    # $cairo->restore;
}

sub _draw_image {
    my ($self, $comp) = @_;

    $self->_draw_component($comp);

    my $cairo = $self->cairo;

    $cairo->save;

    my $imgs = Cairo::ImageSurface->create_from_png($comp->image);

    my $bb = $comp->inside_bounding_box;

    my $bumpx = 0;
    my $bumpy = 0;
    if($comp->horizontal_alignment eq 'center') {
        $bumpx = $bb->width / 2;
        if(defined($comp->scale)) {
            $bumpx -= $comp->scale->[0] * ($imgs->get_width / 2);
        } else {
            $bumpx -= $imgs->get_width / 2;
        }
    } elsif($comp->horizontal_alignment eq 'right') {
        $bumpx = $bb->width;
        if(defined($comp->scale)) {
            $bumpx -= $comp->scale->[0] * $imgs->get_width;
        } else {
            $bumpx -= $imgs->get_width;
        }
    }

    if($comp->vertical_alignment eq 'center') {
        $bumpy = $bb->height / 2;
        if(defined($comp->scale)) {
            $bumpy -= $comp->scale->[1] * ($imgs->get_height / 2);
        } else {
            $bumpy -= $imgs->get_height / 2;
        }
    } elsif($comp->vertical_alignment eq 'bottom') {
        $bumpy = $bb->height;
        if(defined($comp->scale)) {
            $bumpy -= $comp->scale->[1] * $imgs->get_height;
        } else {
            $bumpy -= $imgs->get_height;
        }
    }

    $cairo->translate($bb->origin->x + $bumpx, $bb->origin->y + $bumpy);
    $cairo->rectangle(0, 0, $imgs->get_width, $imgs->get_height);
    $cairo->clip;

    if(defined($comp->scale)) {
        $cairo->scale($comp->scale->[0], $comp->scale->[1]);
    }

    $cairo->rectangle(
       0, 0, $imgs->get_width, $imgs->get_height
    );

    $cairo->set_source_surface($imgs, 0, 0);

    $cairo->fill;

    $cairo->restore;
}

sub _draw_path {
    my ($self, $path, $op) = @_;



    # If preserve count is set we've "preserved" a path that's made up 
    # of X primitives.  Set the sentinel to the the count so we skip that
    # many primitives
    my $pc = $self->_preserve_count;
    # if($pc) {
    #     $self->_preserve_count(0);
    # } else {
        $self->add_js("ctx.beginPath();\n");
    # }

    my $pcount = $path->primitive_count;
    for(my $i = $pc; $i < $pcount; $i++) {
        my $prim = $path->get_primitive($i);
        my $hints = $path->get_hint($i);

        if(defined($hints)) {
            unless($hints->{contiguous}) {
                my $ps = $prim->point_start;
                $self->add_js("ctx.moveTo(".$ps->x.",".$ps->y.");\n");
            }
        }

        # FIXME Check::ISA
        if($prim->isa('Geometry::Primitive::Line')) {
            $self->_draw_line($prim);
        } elsif($prim->isa('Geometry::Primitive::Rectangle')) {
            $self->_draw_rectangle($prim);
        } elsif($prim->isa('Geometry::Primitive::Arc')) {
            $self->_draw_arc($prim);
        } elsif($prim->isa('Geometry::Primitive::Bezier')) {
            $self->_draw_bezier($prim);
        } elsif($prim->isa('Geometry::Primitive::Circle')) {
            $self->_draw_circle($prim);
        } elsif($prim->isa('Geometry::Primitive::Ellipse')) {
            $self->_draw_ellipse($prim);
        } elsif($prim->isa('Geometry::Primitive::Polygon')) {
            $self->_draw_polygon($prim);
        }
    }

    if($op->isa('Graphics::Primitive::Operation::Stroke')) {
        $self->_do_stroke($op);
    } elsif($op->isa('Graphics::Primitive::Operation::Fill')) {
        $self->_do_fill($op);
    }

    if($op->preserve) {
        $self->_preserve_count($path->primitive_count);
    }
}

sub _draw_line {
    my ($self, $line) = @_;

    my $end = $line->end;
    $self->add_js("// Begin Line\n");
    $self->add_js("ctx.lineTo(".$end->x.",".$end->y.");\n");
    $self->add_js("// End Line\n");
}

sub _draw_polygon {
    my ($self, $poly) = @_;

    my $context = $self->cairo;
    for(my $i = 1; $i < $poly->point_count; $i++) {
        my $p = $poly->get_point($i);
        $context->line_to($p->x, $p->y);
    }
    $context->close_path;
}

sub _draw_rectangle {
    my ($self, $rect) = @_;

    my $context = $self->cairo;
    $context->rectangle(
        $rect->origin->x, $rect->origin->y,
        $rect->width, $rect->height
    );
}

sub _do_fill {
    my ($self, $fill) = @_;

    # my $context = $self->cairo;
    my $paint = $fill->paint;

    # FIXME Check::ISA?
    if($paint->isa('Graphics::Primitive::Paint::Gradient')) {

        my $patt;
        if($paint->isa('Graphics::Primitive::Paint::Gradient::Linear')) {
            # $patt = Cairo::LinearGradient->create(
            #     $paint->line->start->x, $paint->line->start->y,
            #     $paint->line->end->x, $paint->line->end->y,
            # );
        } elsif($paint->isa('Graphics::Primitive::Paint::Gradient::Radial')) {
            # $patt = Cairo::RadialGradient->create(
            #     $paint->start->origin->x, $paint->start->origin->y,
            #     $paint->start->radius,
            #     $paint->end->origin->x, $paint->end->origin->y,
            #     $paint->end->radius
            # );
        } else {
            croak('Unknown gradient type: '.ref($paint));
        }

        foreach my $stop ($paint->stops) {
            my $color = $paint->get_stop($stop);
            # $patt->add_color_stop_rgba(
            #     $stop, $color->red, $color->green,
            #     $color->blue, $color->alpha
            # );
        }
        # $context->set_source($patt);

    } elsif($paint->isa('Graphics::Primitive::Paint::Solid')) {
        $self->set_style(undef, $paint->color);
        # $context->set_source_rgba($paint->color->as_array_with_alpha);
    }

    if($fill->preserve) {
        # $context->fill_preserve;
    } else {
        # $context->fill;
    }
    $self->add_js("ctx.fill();\n");
}

sub _do_stroke {
    my ($self, $stroke) = @_;

    my $br = $stroke->brush;

    $self->set_style($br);
    $self->add_js("ctx.stroke();\n");
    # my $context = $self->cairo;
    # $context->set_source_rgba($br->color->as_array_with_alpha);
    # $context->set_line_cap($br->line_cap);
    # $context->set_line_join($br->line_join);
    # $context->set_line_width($br->width);

    my $dash = $br->dash_pattern;
    if(defined($dash) && scalar(@{ $dash })) {
        # $context->set_dash(0, @{ $dash });
    }

    if($stroke->preserve) {
        # $context->stroke_preserve;
    } else {
        # $context->stroke;
    }

    # Reset dashing
    # $context->set_dash(0, []);
}

sub _finish_page {
    my ($self) = @_;

    my $context = $self->cairo;
    $context->show_page;
}

sub _resize {
    my ($self, $width, $height) = @_;

    # Don't resize unless we have to
    if(($self->width != $width) || ($self->height != $height)) {
        $self->surface->set_size($width, $height);
    }
}

sub get_text_bounding_box {
    my ($self, $tb, $text) = @_;

    my $context = $self->cairo;

    my $font = $tb->font;

    unless(defined($text)) {
        $text = $tb->text;
    }

    $context->new_path;

    my $fsize = $font->size;

    my $options = Cairo::FontOptions->create;
    $options->set_antialias($font->antialias_mode);
    $options->set_subpixel_order($font->subpixel_order);
    $options->set_hint_style($font->hint_style);
    $options->set_hint_metrics($font->hint_metrics);
    $context->set_font_options($options);

    # my $key = "$text||".$font->face.'||'.$font->slant.'||'.$font->weight.'||'.$fsize;

    # If our text + font key is found, return the box we already made.
    # if(exists($self->{TBCACHE}->{$key})) {
    #     return ($self->{TBCACHE}->{$key}->[0], $self->{TBCACHE}->{$key}->[1]);
    # }

    # my @exts;
    my $exts;
    if($text eq '') {
        # Catch empty lines.  There's no sense trying to get it's height.  We
        # just set it to the height of the font and move on.
        # @exts = (0, -$font->size, 0, 0);
        $exts->{y_bearing} = 0;
        $exts->{x_bearing} = 0;
        $exts->{x_advance} = 0;
        $exts->{width} = 0;
        $exts->{height} = $fsize;
    } else {
        $context->select_font_face(
            $font->face, $font->slant, $font->weight
        );
        $context->set_font_size($fsize);
        $exts = $context->text_extents($text);
    }

    my $tbr = Geometry::Primitive::Rectangle->new(
        origin  => Geometry::Primitive::Point->new(
            x => $exts->{x_bearing},#$exts[0],
            y => $exts->{y_bearing},#$exts[1],
        ),
        width   => $exts->{width} + $exts->{x_bearing} + 1,#abs($exts[2]) + abs($exts[0]),
        height  => $exts->{height},#$tbsize
    );

    my $cb = $tbr;
    if($tb->angle) {

        $context->save;

        my $tw2 = $tb->width / 2;
        my $th2 = $tb->height / 2;

        $context->translate($tw2, $th2);
        $context->rotate($tb->angle);
        $context->translate(-$tw2, -$th2);

        my ($rw, $rh) = $self->_get_bounding_box($context, $exts);

        $cb = Geometry::Primitive::Rectangle->new(
            origin  => $tbr->origin,
            width   => $rw,
            height  => $rh
        );

        $context->restore;
    }

    # $self->{TBCACHE}->{$key} = [ $cb, $tbr ];

    return ($cb, $tbr);
}

sub get_textbox_layout {
    my ($self, $comp) = @_;

    my $tl = Graphics::Primitive::Driver::Cairo::TextLayout->new(
        component => $comp
    );
    $tl->layout($self);
    return $tl;
}

sub reset {
    my ($self) = @_;

    $self->clear_cairo;
}

sub _get_bounding_box {
    my ($self, $context, $exts) = @_;

    my $lw = $exts->{width} + abs($exts->{x_bearing});
    my $lh = $exts->{height} + abs($exts->{y_bearing});

    my $matrix = $context->get_matrix;
    my @corners = ([0,0], [$lw,0], [$lw,$lh], [0,$lh]);

    # Transform each of the four corners, the find the maximum X and Y
    # coordinates to create a bounding box

    my @points;
    foreach my $pt (@corners) {
        my ($x, $y) = $matrix->transform_point($pt->[0], $pt->[1]);
        push(@points, [ $x, $y ]);
    }

    my $maxX = $points[0]->[0];
    my $maxY = $points[0]->[1];
    my $minX = $points[0]->[0];
    my $minY = $points[0]->[1];

    foreach my $pt (@points) {

        if($pt->[0] > $maxX) {
            $maxX = $pt->[0];
        } elsif($pt->[0] < $minX) {
            $minX = $pt->[0];
        }

        if($pt->[1] > $maxY) {
            $maxY = $pt->[1];
        } elsif($pt->[1] < $minY) {
            $minY = $pt->[1];
        }
    }

    my $bw = $maxX - $minX;
    my $bh = $maxY - $minY;

    return ($bw, $bh);
}

no Moose;
1;
__END__

=head1 NAME

Graphics::Primitive::Driver::Cairo - Cairo backend for Graphics::Primitive

=head1 SYNOPSIS

    use Graphics::Primitive::Component;
    use Graphics::Primitive::Driver::Cairo;

    my $driver = Graphics::Primitive::Driver::Cairo->new;
    my $container = Graphics::Primitive::Container->new(
        width => $form->sheet_width,
        height => $form->sheet_height
    );
    $container->border->width(1);
    $container->border->color($black);
    $container->padding(
        Graphics::Primitive::Insets->new(top => 5, bottom => 5, left => 5, right => 5)
    );
    my $comp = Graphics::Primitive::Component->new;
    $comp->background_color($black);
    $container->add_component($comp, 'c');

    my $lm = Layout::Manager::Compass->new;
    $lm->do_layout($container);

    my $driver = Graphics::Primitive::Driver::Cairo->new(
        format => 'PDF'
    );
    $driver->draw($container);
    $driver->write('/Users/gphat/foo.pdf');

=head1 DESCRIPTION

This module draws Graphics::Primitive objects using Cairo.

=head1 IMPLEMENTATION DETAILS

=over 4

=item B<Borders>

Borders are drawn clockwise starting with the top one.  Since cairo can't do
line-joins on different colored lines, each border overlaps those before it.
This is not the way I'd like it to work, but i'm opting to fix this later.
Consider yourself warned.

=back

=head1 Attributes

=head2 antialias_mode

Set/Get the antialias mode of this driver. Options are default, none, gray and
subpixel.

=head2 cairo

This driver's Cairo::Context object

=head2 data

Get the data in a scalar for this driver.

=item I<format>

Get the format for this driver.

=item I<surface>

Get/Set the surface on which this driver is operating.

=head1 Methods

=item I<new>

Creates a new Graphics::Primitive::Driver::Cairo object.  Requires a format.

  my $driver = Graphics::Primitive::Driver::Cairo->new(format => 'PDF');

=item I<draw>

Draws the specified component.  Container's components are drawn recursively.

=item I<get_text_bounding_box ($font, $text, $angle)>

Returns two L<Rectangles|Graphics::Primitive::Rectangle> that encloses the
supplied text. The origin's x and y maybe negative, meaning that the glyphs in
the text extending left of x or above y.

The first rectangle is the bounding box required for a container that wants to
contain the text.  The second box is only useful if an optional angle is
provided.  This second rectangle is the bounding box of the un-rotated text
that allows for a controlled rotation.  If no angle is supplied then the
two rectangles are actually the same object.

If the optional angle is supplied the text will be rotated by the supplied
amount in radians.

=item I<get_textbox_layout ($tb)>

Returns a L<Graphics::Primitive::Driver::TextLayout> for the supplied
textbox.

=item I<reset>

Reset the driver.

=item I<write>

Write this driver's data to the specified file.

=back

=head1 AUTHOR

Cory Watson, C<< <gphat@cpan.org> >>

=head1 ACKNOWLEDGEMENTS

Danny Luna

=head1 BUGS

Please report any bugs or feature requests to C<bug-geometry-primitive at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Geometry-Primitive>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
