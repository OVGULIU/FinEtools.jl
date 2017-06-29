"""
    FENodeSetModule

Module for finite element node set.
"""
module FENodeSetModule

using FinEtools.FTypesModule
import Base.count

"""
    Finite element node set type.

xyz =
    Array of node locations.
    Array of coordinates, the number of rows corresponds to the number of
    nodes in the set and the columns corresponds to the space dimensions.
    The location of node j is given by x[j,:].

"""
#
type FENodeSet
    xyz::FFltMat

    function FENodeSet(xyz::FFltMat)
        self = new(deepcopy(xyz)); # Need to make a COPY of the input array!
        return self
    end

end
export FENodeSet

"""
    spacedim(self::FENodeSet)

Number of dimensions of the space in which the node lives, 1, 2, or 3.
"""
# Get the  dimension of the coordinate that defines the location  of the node.
spacedim(self::FENodeSet) =size(self.xyz,2)
export spacedim

"""
    xyz3(self::FENodeSet)

Get the  3-D coordinate that define the location  of the node.
Even if the nodes  were specified in  lower dimension (1-D, 2-D)
this function returns  a 3-D coordinate  by padding with zeros.
"""
function xyz3(self::FENodeSet)
    if (size(self.xyz,2)==1)
        val = [self.xyz zeros(size(self.xyz,1),2)];
    elseif (size(self.xyz,2)==2)
        val = [self.xyz zeros(size(self.xyz,1),1)];
    else
        val = self.xyz;
    end
end
export xyz3

"""
    count(self::FENodeSet)

Get the number of finite element nodes in the node set.
"""
function count(self::FENodeSet)
    return size(self.xyz,1)::FInt
end
export count


end