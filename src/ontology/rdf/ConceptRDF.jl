# Copyright 2018 IBM Corp.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module ConceptRDF
export presentation_to_rdf, generator_rdf_node

using Serd
using Catlab

using ...Doctrine, ...Ontology
using ..RDFUtils

const R = RDF.Resource


""" Convert concepts into RDF/OWL ontology.

Concepts are repesented as individuals of the OWL class `Concept`.
"""
function presentation_to_rdf(pres::Presentation, prefix::RDF.Prefix;
                             extra_rdf::Union{Function,Nothing}=nothing)
  stmts = RDF.Statement[
    RDF.Prefix("rdf"), RDF.Prefix("rdfs"), RDF.Prefix("owl"),
    RDF.Prefix("list", "http://www.co-ode.org/ontologies/list.owl#"),
    RDF.Prefix("monocl", "https://www.datascienceontology.org/ns/monocl/"),
    prefix
  ]
  for expr in generators(pres)
    append!(stmts, expr_to_rdf(expr, prefix))
    if extra_rdf != nothing && first(expr) != nothing
      append!(stmts, extra_rdf(expr, generator_rdf_node(expr, prefix)))
    end
  end
  stmts
end

""" Generate RDF for object generator.
"""
function expr_to_rdf(ob::Monocl.Ob{:generator}, prefix::RDF.Prefix)
  node = generator_rdf_node(ob, prefix)
  [ RDF.Triple(node, R("rdf","type"), R("monocl","TypeConcept")),
    RDF.Triple(node, R("monocl","id"), RDF.Literal(string(first(ob)))) ]
end

""" Generate RDF for subobject relation.
"""
function expr_to_rdf(sub::Monocl.SubOb, prefix::RDF.Prefix)
  dom_node = generator_rdf_node(dom(sub), prefix)
  codom_node = generator_rdf_node(codom(sub), prefix)
  [ RDF.Triple(dom_node, R("monocl","subtypeOf"), codom_node) ]
end

""" Generate RDF for morphism generator.

The domain and codomain objects are represented as OWL lists.
"""
function expr_to_rdf(hom::Monocl.Hom{:generator}, prefix::RDF.Prefix)
  node = generator_rdf_node(hom, prefix)
  cell_node = name -> R(prefix.name, "$(node.name):$name")
  input_nodes = [ generator_rdf_node(ob, prefix) for ob in collect(dom(hom)) ]
  output_nodes = [ generator_rdf_node(ob, prefix) for ob in collect(codom(hom)) ]
  nin, nout = length(input_nodes), length(output_nodes)
  RDF.Statement[
    [ RDF.Triple(node, R("rdf","type"), R("monocl","FunctionConcept")),
      RDF.Triple(node, R("monocl","id"), RDF.Literal(string(first(hom)))) ];
    owl_inputs_outputs(node, cell_node, nin, nout, index=true) do cell, is_input, i
      gen_node = (is_input ? input_nodes : output_nodes)[i]
      [ RDF.Triple(cell, R("list","hasContents"), gen_node),
        RDF.Triple(cell, R("monocl","isConcept"), gen_node) ]
    end;
  ]
end

""" Generate RDF for submorphism relation.
"""
function expr_to_rdf(sub::Monocl.SubHom, prefix::RDF.Prefix)
  dom_node = generator_rdf_node(dom(sub), prefix)
  codom_node = generator_rdf_node(codom(sub), prefix)
  [ RDF.Triple(dom_node, R("monocl","subfunctionOf"), codom_node) ]
end

""" Create RDF node for generator expression.
"""
function generator_rdf_node(expr::GATExpr{:generator}, prefix::RDF.Prefix)
  @assert first(expr) != nothing
  R(prefix.name, string(first(expr)))
end

end
